import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/models/task.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTaskScreen(taskToEdit: currentTask),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Task'),
                  content: const Text(
                    'Are you sure you want to delete this task?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await TaskManager.of(context).deleteTask(currentTask.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              Checkbox(
                value: currentTask.isCompleted,
                onChanged: (value) {
                  TaskManager.of(context).toggleTaskComplete(currentTask.id);
                },
              ),
              Expanded(
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
                        child: Text(
                          currentTask.priority.displayName,
                          style: TextStyle(
                            color: currentTask.priority.getColor(context),
                            fontWeight: FontWeight.bold,
                          ),
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
                  if (currentTask.dueDate != null) ...[
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20.0,
                          color: currentTask.isOverdue ? Colors.red : null,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          'Due Date: ',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          dateFormat.format(currentTask.dueDate!),
                          style: TextStyle(
                            color: currentTask.isOverdue ? Colors.red : null,
                            fontWeight: currentTask.isOverdue
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                        if (currentTask.isOverdue) ...[
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
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
}
