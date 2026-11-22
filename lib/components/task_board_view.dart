import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_list_provider.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/models/task_section.dart';
import 'package:zero_trust_tasks/pages/task_details_screen.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

/// What the board's columns are.
enum BoardGrouping { status, due, priority, list }

/// "In progress" on the board: a key in the task's [Task.extra], so a task
/// that was never on the board looks exactly as before, and older versions
/// keep the key when they save the task.
extension TaskBoardStatus on Task {
  static const key = 'boardStatus';
  static const doing = 'doing';

  bool get inProgress => !isCompleted && extra[key] == doing;

  Task withInProgress(bool value) {
    final next = Map<String, dynamic>.of(extra);
    if (value) {
      next[key] = doing;
    } else {
      next.remove(key);
    }
    return copyWith(extra: next);
  }
}

/// One column: its key (what a drop changes), its title and its tasks.
class BoardColumn {
  const BoardColumn(this.key, this.title, this.tasks, {this.acceptsDrops = true});
  final String key;
  final String title;
  final List<Task> tasks;

  /// "Overdue" takes no drops: nothing can be made late by dragging.
  final bool acceptsDrops;
}

/// The board's columns, in order, each with its tasks in the order given.
List<BoardColumn> boardColumns(
  List<Task> tasks,
  BoardGrouping grouping, {
  required List<TaskList> lists,
}) {
  final l10n = currentL10n;
  switch (grouping) {
    case BoardGrouping.status:
      return [
        BoardColumn('todo', l10n.boardToDo, [for (final t in tasks) if (!t.isCompleted && !t.inProgress) t]),
        BoardColumn('doing', l10n.boardInProgress, [for (final t in tasks) if (t.inProgress) t]),
        BoardColumn('done', l10n.completed, [for (final t in tasks) if (t.isCompleted) t]),
      ];
    case BoardGrouping.due:
      final sections = TaskFilterService.groupBySection(tasks);
      return [
        for (final s in TaskSection.values)
          if (s != TaskSection.overdue || sections[s]!.isNotEmpty)
            BoardColumn(s.name, s.displayName, sections[s]!, acceptsDrops: s != TaskSection.overdue),
      ];
    case BoardGrouping.priority:
      return [
        for (final p in TaskPriority.values)
          BoardColumn(p.name, p.displayName, [for (final t in tasks) if (t.priority == p) t]),
      ];
    case BoardGrouping.list:
      final known = {for (final l in lists) l.id};
      String keyOf(Task t) => t.listId != null && known.contains(t.listId) ? t.listId! : TaskList.defaultId;
      return [
        for (final l in lists)
          BoardColumn(l.id, l.name, [for (final t in tasks) if (keyOf(t) == l.id) t]),
      ];
  }
}

/// What dropping [task] on the column [key] changes, or null when nothing
/// changes. "Done" and the list are changed by the caller (completing and
/// moving have their own rules), so here only the task's own fields.
Task? boardDrop(Task task, BoardGrouping grouping, String key, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime onDay(DateTime day) {
    final due = task.dueDate;
    // Keeps the time of day a task had.
    return due == null ? day : DateTime(day.year, day.month, day.day, due.hour, due.minute);
  }

  switch (grouping) {
    case BoardGrouping.status:
      return switch (key) {
        'todo' when task.isCompleted || task.inProgress => task.withInProgress(false).copyWith(isCompleted: false),
        'doing' when !task.inProgress => task.withInProgress(true).copyWith(isCompleted: false),
        _ => null,
      };
    case BoardGrouping.due:
      final reopened = task.isCompleted ? task.copyWith(isCompleted: false) : task;
      if (key == TaskSection.today.name) return reopened.copyWith(dueDate: onDay(today));
      if (key == TaskSection.upcoming.name) {
        final due = task.dueDate;
        final alreadyLater = due != null && !due.isBefore(today.add(const Duration(days: 1)));
        return alreadyLater && !task.isCompleted ? null : reopened.copyWith(dueDate: onDay(today.add(const Duration(days: 1))));
      }
      if (key == TaskSection.noDueDate.name) {
        return task.dueDate == null && !task.isCompleted ? null : reopened.copyWith(clearDueDate: true);
      }
      return null;
    case BoardGrouping.priority:
      final p = TaskPriority.values.asNameMap()[key];
      return p == null || p == task.priority ? null : task.copyWith(priority: p);
    case BoardGrouping.list:
      return null;
  }
}

/// The tasks as columns side by side: by status (to do, in progress,
/// done), due date, priority or list. Long-press a card and drag it to
/// another column to change that.
class TaskBoardView extends ConsumerStatefulWidget {
  const TaskBoardView({super.key, required this.tasks, required this.grouping, required this.onGroupingChanged});

  final List<Task> tasks;
  final BoardGrouping grouping;
  final ValueChanged<BoardGrouping> onGroupingChanged;

  @override
  ConsumerState<TaskBoardView> createState() => _TaskBoardViewState();
}

class _TaskBoardViewState extends ConsumerState<TaskBoardView> {
  Future<void> _drop(Task task, BoardColumn column) async {
    final manager = ref.read(taskManagerProvider);
    final grouping = widget.grouping;
    if (grouping == BoardGrouping.list) {
      await manager.moveToList({task.id}, column.key);
      return;
    }
    final done = (grouping == BoardGrouping.status && column.key == 'done') ||
        (grouping == BoardGrouping.due && column.key == TaskSection.completed.name);
    if (done) {
      if (!task.isCompleted) {
        final cleared = task.inProgress ? task.withInProgress(false) : null;
        if (cleared != null) await manager.updateTask(cleared);
        await manager.toggleTaskComplete(task.id);
      }
      return;
    }
    final changed = boardDrop(task, grouping, column.key, DateTime.now());
    if (changed == null) return;
    if (task.isCompleted && !changed.isCompleted) {
      // Reopened the usual way (repeats and reminders), then the change.
      await manager.toggleTaskComplete(task.id);
      final reopened = manager.tasks.where((t) => t.id == task.id).firstOrNull;
      if (reopened == null) return;
      await manager.updateTask(boardDrop(reopened, grouping, column.key, DateTime.now()) ?? reopened);
      return;
    }
    await manager.updateTask(changed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TaskListProvider lists = ref.watch(taskListProvider);
    final columns = boardColumns(widget.tasks, widget.grouping, lists: lists.lists);
    final width = MediaQuery.sizeOf(context).width;
    // Phones: one column and a bit of the next; wide screens: fit them all.
    final columnWidth = width >= 840 ? ((width - 32) / columns.length).clamp(240.0, 360.0) : (width * 0.8).clamp(240.0, 320.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<BoardGrouping>(
              segments: [
                ButtonSegment(value: BoardGrouping.status, label: Text(l10n.boardByStatus)),
                ButtonSegment(value: BoardGrouping.due, label: Text(l10n.boardByDue)),
                ButtonSegment(value: BoardGrouping.priority, label: Text(l10n.boardByPriority)),
                ButtonSegment(value: BoardGrouping.list, label: Text(l10n.boardByList)),
              ],
              selected: {widget.grouping},
              showSelectedIcon: false,
              onSelectionChanged: (s) => widget.onGroupingChanged(s.single),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 16),
            children: [
              for (final c in columns)
                SizedBox(
                  width: columnWidth,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: _BoardColumnView(column: c, onDrop: (t) => _drop(t, c)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardColumnView extends StatelessWidget {
  const _BoardColumnView({required this.column, required this.onDrop});
  final BoardColumn column;
  final void Function(Task) onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => column.acceptsDrops && !column.tasks.any((t) => t.id == d.data.id),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      column.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${column.tasks.length}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: column.tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          column.acceptsDrops ? context.l10n.boardDropHere : '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      itemCount: column.tasks.length,
                      itemBuilder: (context, i) => _BoardCard(task: column.tasks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TaskDetailsScreen(task: task))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(task.priority.icon, size: 16, color: task.priority.getColor(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: task.isCompleted ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                    ),
                  ),
                ],
              ),
              if (task.dueDate != null || task.subTasks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    if (task.dueDate != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.event, size: 14),
                        const SizedBox(width: 4),
                        Text(DateFormat.MMMd().format(task.dueDate!), style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    if (task.subTasks.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.checklist, size: 14),
                        const SizedBox(width: 4),
                        Text('${task.completedSubTasksCount}/${task.subTasks.length}', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<Task>(
        data: task,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: constraints.maxWidth, child: Opacity(opacity: 0.9, child: card)),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      ),
    );
  }
}
