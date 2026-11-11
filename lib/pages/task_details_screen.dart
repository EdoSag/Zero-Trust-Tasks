import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/components/linked_items_section.dart';
import 'package:zero_trust_tasks/components/task_list_dialogs.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/core/services/task_urgency_service.dart';
import 'package:zero_trust_tasks/core/utils/snackbar_helper.dart';
import 'package:zero_trust_tasks/models/task_template.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/places/task_place_reminders.dart';
import 'package:zt_places/zt_places.dart';

enum _TaskAction { moveToList, makeSubtask, duplicate, saveAsTemplate, archive, delete }

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<TaskDetailsScreen> createState() {
    return _TaskDetailsScreenState();
  }
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final taskManager = ref.watch(taskManagerProvider);
    final currentTask = taskManager.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    final dateFormat = DateFormat.yMMMd();
    final urgency = TaskUrgencyService.getUrgency(currentTask);
    final urgencyColor = TaskUrgencyService.getColor(urgency, context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.taskDetails),
        actions: [
          IconButton(
            icon: Icon(
              currentTask.starred ? Icons.star : Icons.star_border,
              color: currentTask.starred ? Colors.amber.shade700 : null,
            ),
            tooltip: currentTask.starred ? context.l10n.removeStar : context.l10n.star,
            onPressed: () => context.taskManager.toggleStar(currentTask.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.editTask2,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTaskScreen(taskToEdit: currentTask),
                ),
              );
            },
          ),
          PopupMenuButton<_TaskAction>(
            onSelected: (action) {
              switch (action) {
                case _TaskAction.moveToList:
                  _moveToList(context, currentTask);
                case _TaskAction.makeSubtask:
                  _makeSubtask(context, currentTask);
                case _TaskAction.duplicate:
                  _duplicateTask(context, currentTask);
                case _TaskAction.saveAsTemplate:
                  _saveAsTemplate(context, currentTask);
                case _TaskAction.archive:
                  _archiveTask(context, currentTask);
                case _TaskAction.delete:
                  _deleteTask(context, currentTask);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TaskAction.moveToList,
                child: ListTile(
                  leading: Icon(Icons.drive_file_move_outline),
                  title: Text(context.l10n.moveToList),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _TaskAction.makeSubtask,
                child: ListTile(
                  leading: Icon(Icons.format_indent_increase),
                  title: Text(context.l10n.makeASubtaskOf),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _TaskAction.duplicate,
                child: ListTile(
                  leading: Icon(Icons.copy_outlined),
                  title: Text(context.l10n.duplicate),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _TaskAction.saveAsTemplate,
                child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text(context.l10n.saveAsTemplate),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _TaskAction.archive,
                child: ListTile(
                  leading: Icon(
                    currentTask.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(currentTask.isArchived ? context.l10n.unarchive : context.l10n.archive),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _TaskAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(context.l10n.delete, style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              Semantics(
                label: currentTask.isCompleted
                    ? context.l10n.markNotCompleted(currentTask.title)
                    : context.l10n.markCompleted(currentTask.title),
                child: Checkbox(
                  value: currentTask.isCompleted,
                  onChanged: (value) => _toggleComplete(context, currentTask),
                ),
              ),
              Expanded(
                child: Hero(
                  tag: 'task-title-${currentTask.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      currentTask.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: currentTask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentTask.description != null) ...[
                    Text(
                      context.l10n.description,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(currentTask.description!),
                    const SizedBox(height: 16.0),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.flag, size: 20.0),
                      const SizedBox(width: 8.0),
                      Text(
                        context.l10n.priority2,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: currentTask.priority
                              .getColor(context)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentTask.priority.icon,
                              size: 14.0,
                              color: currentTask.priority.getColor(context),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              currentTask.priority.displayName,
                              style: TextStyle(
                                color: currentTask.priority.getColor(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (currentTask.category != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        const Icon(Icons.label, size: 20.0),
                        const SizedBox(width: 8.0),
                        Text(
                          context.l10n.category2,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(currentTask.category!),
                      ],
                    ),
                  ],
                  if (currentTask.startDate != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline, size: 20.0),
                        const SizedBox(width: 8.0),
                        Text(
                          context.l10n.startDate,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(dateFormat.format(currentTask.startDate!)),
                      ],
                    ),
                  ],
                  if (currentTask.dueDate != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Icon(
                          TaskUrgencyService.getIcon(urgency),
                          size: 20.0,
                          color: urgency == TaskUrgency.normal ||
                                  urgency == TaskUrgency.none
                              ? null
                              : urgencyColor,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          context.l10n.due,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _formatDueDate(currentTask.dueDate!),
                          style: TextStyle(
                            color: urgency == TaskUrgency.normal ||
                                    urgency == TaskUrgency.none
                                ? null
                                : urgencyColor,
                            fontWeight: currentTask.isOverdue
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                        if (TaskUrgencyService.getLabel(urgency).isNotEmpty) ...[
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: urgencyColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              TaskUrgencyService.getLabel(urgency).toUpperCase(),
                              style: TextStyle(
                                color: urgencyColor,
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (currentTask.recurrence != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        const Icon(Icons.repeat, size: 20.0),
                        const SizedBox(width: 8.0),
                        Text(
                          context.l10n.repeats,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(currentTask.recurrence!.frequency.displayName),
                        if (currentTask.recurrence!.interval > 1)
                          Text(context.l10n.everyN(currentTask.recurrence!.interval)),
                      ],
                    ),
                  ],
                  if (currentTask.reminderAt != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        const Icon(Icons.notifications_outlined, size: 20.0),
                        const SizedBox(width: 8.0),
                        Text(
                          context.l10n.reminder,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(DateFormat.yMMMd().add_jm().format(currentTask.reminderAt!)),
                      ],
                    ),
                  ],
                  if (ref.watch(placeRemindersProvider).forTask(currentTask.id) case final place?) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 20.0),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            place.trigger == ZtPlaceTrigger.arrive
                                ? context.l10n.remindArriveAt(place.place.name.isEmpty ? context.l10n.aPlace : place.place.name)
                                : context.l10n.remindLeave(place.place.name.isEmpty ? context.l10n.aPlace : place.place.name),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (currentTask.tags.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: currentTask.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              avatar: const Icon(Icons.tag, size: 14),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (currentTask.notes != null) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      context.l10n.notes,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(currentTask.notes!),
                  ],
                  if (currentTask.links.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      context.l10n.links,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    ...currentTask.links.map(
                      (link) => InkWell(
                        onTap: () => _launchUrl(link),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 16.0, color: Colors.blue),
                              const SizedBox(width: 4.0),
                              Expanded(
                                child: Text(
                                  link,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12.0),
                  LinkedItemsSection(
                    noteIds: currentTask.noteIds,
                    contactIds: currentTask.contactIds,
                    onChanged: (notes, contacts) => context.taskManager.updateTask(
                      currentTask.copyWith(noteIds: notes, contactIds: contacts),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (currentTask.subTasks.isNotEmpty) ...[
            const SizedBox(height: 24.0),
            Text(
              context.l10n.subtasksProgress(currentTask.completedSubTasksCount, currentTask.subTasks.length),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            ...currentTask.subTasks.map(
              (subTask) => Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: CheckboxListTile(
                  value: subTask.isCompleted,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: IconButton(
                    icon: const Icon(Icons.format_indent_decrease),
                    tooltip: context.l10n.promoteSubtask(subTask.title),
                    onPressed: () => _promoteSubTask(context, currentTask, subTask.id),
                  ),
                  onChanged: (value) {
                    context.taskManager.toggleSubTaskComplete(currentTask.id, subTask.id);
                  },
                  title: Text(
                    subTask.title,
                    style: TextStyle(
                      decoration: subTask.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24.0),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.createdOn(dateFormat.format(currentTask.createdAt)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    context.l10n.updatedOn(dateFormat.format(currentTask.updatedAt)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToList(BuildContext context, Task task) async {
    final listId = await TaskListDialogs.pick(context, currentId: task.listId);
    if (listId == null || !context.mounted) return;
    await context.taskManager.moveToList({task.id}, listId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.movedTo(context.taskLists.byId(listId).name))),
      );
    }
  }

  Future<void> _makeSubtask(BuildContext context, Task task) async {
    final parent = await TaskListDialogs.pickParent(context, task);
    if (parent == null || !context.mounted) return;
    final manager = context.taskManager;
    await manager.makeSubtaskOf(task.id, parent.id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(context.l10n.nowSubtaskOf(parent.title)),
      // Flutter keeps a snackbar with a button until dismissed unless told
      // otherwise.
      persist: false,
      action: SnackBarAction(
        label: context.l10n.undo,
        onPressed: () async {
          final current = manager.tasks.where((t) => t.id == parent.id).firstOrNull;
          if (current != null) await manager.updateTask(parent.copyWith(subTasks: current.subTasks.take(parent.subTasks.length).toList()));
          await manager.restoreFromTrash(task.id);
        },
      ),
    ));
  }

  Future<void> _promoteSubTask(BuildContext context, Task task, String subTaskId) async {
    final promoted = await context.taskManager.promoteSubTask(task.id, subTaskId);
    if (promoted != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nowOwnTask(promoted.title))),
      );
    }
  }

  Future<void> _duplicateTask(BuildContext context, Task task) async {
    await context.taskManager.duplicateTask(task.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.taskDuplicated)),
      );
    }
  }

  Future<void> _saveAsTemplate(BuildContext context, Task task) async {
    final nameCtrl = TextEditingController(text: task.title);
    final name = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(context.l10n.saveAsTemplate),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: context.l10n.templateName),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(dCtx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, nameCtrl.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;

    final template = TaskTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: name,
      description: task.description,
      category: task.category,
      priority: task.priority,
      tags: List.of(task.tags),
      notes: task.notes,
      links: List.of(task.links),
      subTaskTitles: task.subTasks.map((s) => s.title).toList(),
      recurrence: task.recurrence,
    );

    await context.templates.addTemplate(template);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.templateSaved)),
      );
    }
  }

  Future<void> _archiveTask(BuildContext context, Task task) async {
    final taskManager = context.taskManager;
    if (task.isArchived) {
      await taskManager.unarchiveTask(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.taskUnarchived)),
        );
      }
    } else {
      await taskManager.archiveTask(task.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.taskArchived)),
        );
      }
    }
  }

  String _formatDueDate(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0;
    return hasTime
        ? DateFormat.yMMMd().add_jm().format(date)
        : DateFormat.yMMMd().format(date);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleComplete(BuildContext context, Task task) async {
    final taskManager = context.taskManager;
    final wasCompleted = task.isCompleted;
    try {
      await taskManager.toggleTaskComplete(task.id);
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          context.l10n.updateFailed(e.toString()),
          onRetry: () => _toggleComplete(context, task),
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasCompleted ? context.l10n.taskMarkedIncomplete : context.l10n.taskCompleted),
        // Flutter keeps a snackbar with a button until dismissed unless told
        // otherwise.
        persist: false,
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () {
            taskManager.toggleTaskComplete(task.id);
          },
        ),
      ),
    );
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final taskManager = context.taskManager;
    try {
      await taskManager.deleteTask(task.id);
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          context.l10n.deleteFailed(e.toString()),
          onRetry: () => _deleteTask(context, task),
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.taskDeleted),
        // Flutter keeps a snackbar with a button until dismissed unless told
        // otherwise.
        persist: false,
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () {
            taskManager.undoDelete();
          },
        ),
      ),
    );
  }
}
