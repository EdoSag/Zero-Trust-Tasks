import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

/// Distinguishes "you have no tasks at all" from "your filters/search
/// matched nothing" so the user gets an actionable, accurate message.
enum EmptyTasksReason { noTasksAtAll, noMatchingFilters }

@NowaGenerated()
class EmptyTasksWidget extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const EmptyTasksWidget({
    super.key,
    this.reason = EmptyTasksReason.noTasksAtAll,
    this.onClearFilters,
    this.onCreateTask,
  });

  final EmptyTasksReason reason;

  /// Called when the user taps "Clear filters" (only shown for
  /// [EmptyTasksReason.noMatchingFilters]).
  final VoidCallback? onClearFilters;

  /// Called when the user taps "Create task" (only shown for
  /// [EmptyTasksReason.noTasksAtAll]).
  final VoidCallback? onCreateTask;

  @override
  Widget build(BuildContext context) {
    final isNoMatches = reason == EmptyTasksReason.noMatchingFilters;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNoMatches ? Icons.search_off : Icons.task_alt,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isNoMatches ? 'No matching tasks' : 'No tasks yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNoMatches
                  ? 'No tasks match your current search or filters'
                  : 'Create your first task to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            if (isNoMatches && onClearFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear filters'),
              ),
            ],
            if (!isNoMatches && onCreateTask != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add),
                label: const Text('Create task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
