import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/pages/task_details_screen.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/core/services/task_urgency_service.dart';

@NowaGenerated()
class TaskCard extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const TaskCard({
    super.key,
    required this.task,
    this.selectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectionToggle,
  });

  final Task task;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final urgency = TaskUrgencyService.getUrgency(task);
    final urgencyColor = TaskUrgencyService.getColor(urgency, context);
    final hasSubTasks = task.subTasks.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1.0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: selectionMode
            ? onSelectionToggle
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailsScreen(task: task),
                  ),
                ),
        onLongPress: selectionMode ? null : onLongPress,
        child: Stack(
          children: [
            IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.0,
                color: urgency == TaskUrgency.none
                    ? Colors.transparent
                    : urgencyColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            label: task.isCompleted
                                ? 'Mark "${task.title}" as not completed'
                                : 'Mark "${task.title}" as completed',
                            child: Checkbox(
                              value: task.isCompleted,
                              onChanged: (value) {
                                _toggleComplete(context);
                              },
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Hero(
                                  tag: 'task-title-${task.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(
                                      task.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            decoration: task.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ),
                                if (task.description != null) ...[
                                  const SizedBox(height: 4.0),
                                  Text(
                                    task.description!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: task.priority
                                  .getColor(context)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.priority.icon,
                                  size: 12.0,
                                  color: task.priority.getColor(context),
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  task.priority.displayName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: task.priority.getColor(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (task.dueDate != null ||
                          task.category != null ||
                          task.recurrence != null ||
                          hasSubTasks) ...[
                        const SizedBox(height: 12.0),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            if (task.dueDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: urgency == TaskUrgency.overdue ||
                                          urgency == TaskUrgency.dueToday
                                      ? urgencyColor.withValues(alpha: 0.1)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      TaskUrgencyService.getIcon(urgency),
                                      size: 12.0,
                                      color: urgencyColor,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      TaskUrgencyService.getLabel(
                                                urgency,
                                              ).isNotEmpty
                                          ? '${TaskUrgencyService.getLabel(urgency)} • ${dateFormat.format(task.dueDate!)}'
                                          : dateFormat.format(task.dueDate!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: urgencyColor),
                                    ),
                                  ],
                                ),
                              ),
                            if (task.recurrence != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.repeat,
                                      size: 12.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      task.recurrence!.frequency.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            if (task.category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.label,
                                      size: 12.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      task.category!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasSubTasks)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.checklist,
                                      size: 12.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '${task.completedSubTasksCount}/${task.subTasks.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (hasSubTasks) ...[
                        const SizedBox(height: 8.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: LinearProgressIndicator(
                            value: task.completedSubTasksCount /
                                task.subTasks.length,
                            minHeight: 4.0,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            if (selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComplete(BuildContext context) async {
    final taskManager = TaskManager.of(context);
    final wasCompleted = task.isCompleted;
    await taskManager.toggleTaskComplete(task.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasCompleted ? 'Task marked incomplete' : 'Task completed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            taskManager.toggleTaskComplete(task.id);
          },
        ),
      ),
    );
  }
}
