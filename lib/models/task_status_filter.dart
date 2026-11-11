import 'package:zero_trust_tasks/l10n/l10n.dart';
/// High-level status buckets used both as quick filters on the tasks list
/// and as the target filter when navigating in from the dashboard.
enum TaskStatusFilter { pending, completed, overdue, today, upcoming }

extension TaskStatusFilterExtension on TaskStatusFilter {
  String get displayName {
    switch (this) {
      case TaskStatusFilter.pending:
        return currentL10n.pending;
      case TaskStatusFilter.completed:
        return currentL10n.completed;
      case TaskStatusFilter.overdue:
        return currentL10n.overdue;
      case TaskStatusFilter.today:
        return currentL10n.dueToday2;
      case TaskStatusFilter.upcoming:
        return currentL10n.upcoming;
    }
  }
}
