import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// Computes the next due date for a recurring task.
class RecurrenceService {
  RecurrenceService._();

  /// Returns the next occurrence date after [task.dueDate], or null if the
  /// task has no recurrence rule or no due date.
  static DateTime? nextOccurrence(Task task) {
    final rule = task.recurrence;
    final base = task.dueDate;
    if (rule == null || base == null) return null;

    final int interval = rule.interval.clamp(1, 365).toInt();

    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        return base.add(Duration(days: interval));

      case RecurrenceFrequency.weekly:
        final weekdays = rule.weekdays;
        if (weekdays == null || weekdays.isEmpty) {
          return base.add(Duration(days: 7 * interval));
        }
        final sorted = (List<int>.from(weekdays))..sort();
        // Find a later weekday in the same week
        for (final wd in sorted) {
          if (wd > base.weekday) {
            return base.add(Duration(days: wd - base.weekday));
          }
        }
        // Wrap: jump to the first weekday of the next interval-week.
        // daysToNextMonday = 8 - base.weekday (Mon=1→7 days, Sun=7→1 day)
        final daysToNextMonday = 8 - base.weekday;
        final targetMonday =
            base.add(Duration(days: daysToNextMonday + (interval - 1) * 7));
        return targetMonday.add(Duration(days: sorted.first - 1));

      case RecurrenceFrequency.monthly:
        int month = base.month + interval;
        int year = base.year + (month - 1) ~/ 12;
        month = ((month - 1) % 12) + 1;
        final lastDayOfMonth = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, base.day.clamp(1, lastDayOfMonth).toInt());

      case RecurrenceFrequency.yearly:
        return DateTime(base.year + interval, base.month, base.day);
    }
  }

  /// Returns true if the recurrence has ended relative to [nextDate].
  static bool hasEnded(RecurrenceRule rule, DateTime nextDate) {
    if (rule.endDate != null &&
        nextDate.isAfter(rule.endDate!.add(const Duration(days: 1)))) {
      return true;
    }
    return false;
  }
}
