import 'package:zero_trust_tasks/l10n/l10n.dart';
/// Sections used to group tasks in the list view (item 12 — Today /
/// Upcoming / Overdue / Completed / No due date).
enum TaskSection { overdue, today, upcoming, noDueDate, completed }

extension TaskSectionExtension on TaskSection {
  String get displayName {
    switch (this) {
      case TaskSection.overdue:
        return currentL10n.overdue;
      case TaskSection.today:
        return currentL10n.today;
      case TaskSection.upcoming:
        return currentL10n.upcoming;
      case TaskSection.noDueDate:
        return currentL10n.noDueDate;
      case TaskSection.completed:
        return currentL10n.completed;
    }
  }
}
