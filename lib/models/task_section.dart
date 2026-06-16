/// Sections used to group tasks in the list view (item 12 — Today /
/// Upcoming / Overdue / Completed / No due date).
enum TaskSection { overdue, today, upcoming, noDueDate, completed }

extension TaskSectionExtension on TaskSection {
  String get displayName {
    switch (this) {
      case TaskSection.overdue:
        return 'Overdue';
      case TaskSection.today:
        return 'Today';
      case TaskSection.upcoming:
        return 'Upcoming';
      case TaskSection.noDueDate:
        return 'No due date';
      case TaskSection.completed:
        return 'Completed';
    }
  }
}
