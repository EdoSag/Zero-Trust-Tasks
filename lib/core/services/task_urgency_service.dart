import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// Buckets a task's due date into an urgency tier so the UI can
/// communicate urgency via color *and* icon/label (not color alone).
enum TaskUrgency { overdue, dueToday, dueSoon, normal, none }

class TaskUrgencyService {
  TaskUrgencyService._();

  static TaskUrgency getUrgency(Task task) {
    final dueDate = task.dueDate;
    if (dueDate == null || task.isCompleted) {
      return TaskUrgency.none;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final dayDiff = due.difference(today).inDays;

    if (dayDiff < 0) {
      return TaskUrgency.overdue;
    } else if (dayDiff == 0) {
      return TaskUrgency.dueToday;
    } else if (dayDiff <= 3) {
      return TaskUrgency.dueSoon;
    }
    return TaskUrgency.normal;
  }

  static Color getColor(TaskUrgency urgency, BuildContext context) {
    switch (urgency) {
      case TaskUrgency.overdue:
        return Colors.red;
      case TaskUrgency.dueToday:
        return Colors.deepOrange;
      case TaskUrgency.dueSoon:
        return Colors.amber.shade800;
      case TaskUrgency.normal:
      case TaskUrgency.none:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  static IconData getIcon(TaskUrgency urgency) {
    switch (urgency) {
      case TaskUrgency.overdue:
        return Icons.warning_amber_rounded;
      case TaskUrgency.dueToday:
        return Icons.today;
      case TaskUrgency.dueSoon:
        return Icons.schedule;
      case TaskUrgency.normal:
      case TaskUrgency.none:
        return Icons.calendar_today;
    }
  }

  static String getLabel(TaskUrgency urgency) {
    switch (urgency) {
      case TaskUrgency.overdue:
        return 'Overdue';
      case TaskUrgency.dueToday:
        return 'Due today';
      case TaskUrgency.dueSoon:
        return 'Due soon';
      case TaskUrgency.normal:
        return '';
      case TaskUrgency.none:
        return '';
    }
  }
}
