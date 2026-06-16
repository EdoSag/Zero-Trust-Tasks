import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/components/confirmation_dialog.dart';

/// Shows soft-deleted tasks. Tasks are auto-purged after 30 days.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final taskManager = TaskManager.of(context, listen: true);
    final trashed = taskManager.getTrashedTasks();
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (trashed.isNotEmpty)
            TextButton(
              onPressed: () => _emptyTrash(context, taskManager, trashed.length),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: trashed.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trash is empty',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleted tasks are kept for 30 days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Tasks are permanently deleted after 30 days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: trashed.length,
                    itemBuilder: (context, index) {
                      final task = trashed[index];
                      final daysLeft = 30 -
                          DateTime.now()
                              .difference(task.deletedAt!)
                              .inDays
                              .clamp(0, 30);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            task.title,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            'Deleted ${dateFormat.format(task.deletedAt!)} · $daysLeft day${daysLeft == 1 ? '' : 's'} left',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: 'Restore',
                                onPressed: () =>
                                    _restore(context, taskManager, task.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever),
                                tooltip: 'Delete forever',
                                onPressed: () => _deletePermanently(
                                  context,
                                  taskManager,
                                  task.id,
                                  task.title,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    TaskManager taskManager,
    String taskId,
  ) async {
    await taskManager.restoreFromTrash(taskId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task restored')),
      );
    }
  }

  Future<void> _deletePermanently(
    BuildContext context,
    TaskManager taskManager,
    String taskId,
    String title,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete forever?',
      message: '"$title" will be permanently deleted and cannot be recovered.',
      confirmPhrase: 'DELETE',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      await taskManager.permanentlyDeleteTask(taskId);
    }
  }

  Future<void> _emptyTrash(
    BuildContext context,
    TaskManager taskManager,
    int count,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Empty trash?',
      message: 'All $count task${count == 1 ? '' : 's'} will be permanently deleted.',
      confirmPhrase: 'DELETE',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      final ids = taskManager.getTrashedTasks().map((t) => t.id).toList();
      for (final id in ids) {
        await taskManager.permanentlyDeleteTask(id);
      }
    }
  }
}
