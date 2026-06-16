enum TaskSortOption { dueDateAsc, dueDateDesc, priority, createdDate, alphabetical }

extension TaskSortOptionExtension on TaskSortOption {
  String get displayName {
    switch (this) {
      case TaskSortOption.dueDateAsc:
        return 'Due date (earliest first)';
      case TaskSortOption.dueDateDesc:
        return 'Due date (latest first)';
      case TaskSortOption.priority:
        return 'Priority';
      case TaskSortOption.createdDate:
        return 'Date created';
      case TaskSortOption.alphabetical:
        return 'Alphabetical';
    }
  }
}
