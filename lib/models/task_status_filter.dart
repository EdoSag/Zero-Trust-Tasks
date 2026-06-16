/// High-level status buckets used both as quick filters on the tasks list
/// and as the target filter when navigating in from the dashboard.
enum TaskStatusFilter { pending, completed, overdue, today, upcoming }

extension TaskStatusFilterExtension on TaskStatusFilter {
  String get displayName {
    switch (this) {
      case TaskStatusFilter.pending:
        return 'Pending';
      case TaskStatusFilter.completed:
        return 'Completed';
      case TaskStatusFilter.overdue:
        return 'Overdue';
      case TaskStatusFilter.today:
        return 'Due today';
      case TaskStatusFilter.upcoming:
        return 'Upcoming';
    }
  }
}
