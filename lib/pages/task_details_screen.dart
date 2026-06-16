import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/core/services/task_urgency_service.dart';
import 'package:zero_trust_tasks/core/utils/snackbar_helper.dart';
import 'package:zero_trust_tasks/globals/template_provider.dart';
import 'package:zero_trust_tasks/models/task_template.dart';

enum _TaskAction { duplicate, saveAsTemplate, archive, delete }

@NowaGenerated()
class TaskDetailsScreen extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const TaskDetailsScreen({required this.task, super.key});

  final Task task;

  @override
  State<TaskDetailsScreen> createState() {
    return _TaskDetailsScreenState();
  }
}

@NowaGenerated()
class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final taskManager = TaskManager.of(context, listen: true);
    final currentTask = taskManager.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task,
    );
    final dateFormat = DateFormat('MMM dd, yyyy');
    final urgency = TaskUrgencyService.getUrgency(currentTask);
    final urgencyColor = TaskUrgencyService.getColor(urgency, context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit task',
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
              const PopupMenuItem(
                value: _TaskAction.duplicate,
                child: ListTile(
                  leading: Icon(Icons.copy_outlined),
                  title: Text('Duplicate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _TaskAction.saveAsTemplate,
                child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text('Save as template'),
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
                  title: Text(currentTask.isArchived ? 'Unarchive' : 'Archive'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: _TaskAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
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
                    ? 'Mark "${currentTask.title}" as not completed'
                    : 'Mark "${currentTask.title}" as completed',
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
                      'Description',
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
                        'Priority: ',
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
                          'Category: ',
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
                          'Start Date: ',
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
                          'Due: ',
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
                          'Repeats: ',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(currentTask.recurrence!.frequency.displayName),
                        if (currentTask.recurrence!.interval > 1)
                          Text(' every ${currentTask.recurrence!.interval}'),
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
                          'Reminder: ',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(DateFormat('MMM dd, yyyy • h:mm a').format(currentTask.reminderAt!)),
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
                      'Notes',
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
                      'Links',
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
                ],
              ),
            ),
          ),
          if (currentTask.subTasks.isNotEmpty) ...[
            const SizedBox(height: 24.0),
            Text(
              'Sub-tasks (${currentTask.completedSubTasksCount}/${currentTask.subTasks.length})',
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
                  onChanged: (value) {
                    TaskManager.of(
                      context,
                    ).toggleSubTaskComplete(currentTask.id, subTask.id);
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
                    'Created: ${dateFormat.format(currentTask.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Last updated: ${dateFormat.format(currentTask.updatedAt)}',
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

  Future<void> _duplicateTask(BuildContext context, Task task) async {
    await TaskManager.of(context).duplicateTask(task.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task duplicated')),
      );
    }
  }

  Future<void> _saveAsTemplate(BuildContext context, Task task) async {
    final nameCtrl = TextEditingController(text: task.title);
    final name = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Template name'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(dCtx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, nameCtrl.text.trim()),
            child: const Text('Save'),
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

    await TemplateProvider.of(context, listen: false).addTemplate(template);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved')),
      );
    }
  }

  Future<void> _archiveTask(BuildContext context, Task task) async {
    final taskManager = TaskManager.of(context);
    if (task.isArchived) {
      await taskManager.unarchiveTask(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task unarchived')),
        );
      }
    } else {
      await taskManager.archiveTask(task.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task archived')),
        );
      }
    }
  }

  String _formatDueDate(DateTime date) {
    final hasTime = date.hour != 0 || date.minute != 0;
    return hasTime
        ? DateFormat('MMM dd, yyyy • h:mm a').format(date)
        : DateFormat('MMM dd, yyyy').format(date);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleComplete(BuildContext context, Task task) async {
    final taskManager = TaskManager.of(context);
    final wasCompleted = task.isCompleted;
    try {
      await taskManager.toggleTaskComplete(task.id);
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Failed to update task: ${e.toString()}',
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

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final taskManager = TaskManager.of(context);
    try {
      await taskManager.deleteTask(task.id);
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Failed to delete task: ${e.toString()}',
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
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            taskManager.undoDelete();
          },
        ),
      ),
    );
  }
}
