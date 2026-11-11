import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Distinguishes "you have no tasks at all" from "your filters/search
/// matched nothing" so the user gets an actionable, accurate message.
enum EmptyTasksReason { noTasksAtAll, noMatchingFilters }

class EmptyTasksWidget extends StatelessWidget {
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
              isNoMatches ? context.l10n.noMatchingTasks : context.l10n.noTasksYet,
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
                  ? context.l10n.noTasksMatchYourCurrent
                  : context.l10n.createYourFirstTaskTo,
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
                label: Text(context.l10n.clearFilters),
              ),
            ],
            if (!isNoMatches && onCreateTask != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.createTask),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
