import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/components/confirmation_dialog.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Shows soft-deleted tasks. Tasks are auto-purged after 30 days.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskManager = ref.watch(taskManagerProvider);
    final trashed = taskManager.getTrashedTasks();
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trash),
        actions: [
          if (trashed.isNotEmpty)
            TextButton(
              onPressed: () => _emptyTrash(context, taskManager, trashed.length),
              child: Text(context.l10n.empty),
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
                    context.l10n.trashIsEmpty,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.deletedTasksAreKeptFor2,
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
                    context.l10n.tasksArePermanentlyDeletedAfter,
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
                            context.l10n.deletedDaysLeft(daysLeft, dateFormat.format(task.deletedAt!)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: context.l10n.restore,
                                onPressed: () =>
                                    _restore(context, taskManager, task.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever),
                                tooltip: context.l10n.deleteForever,
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
        SnackBar(content: Text(context.l10n.taskRestored)),
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
      title: context.l10n.deleteForever2,
      message: context.l10n.permDeleteOne(title),
      confirmPhrase: context.l10n.deletePhrase,
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
      title: context.l10n.emptyTrash,
      message: context.l10n.permDeleteAll(count),
      confirmPhrase: context.l10n.deletePhrase,
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
