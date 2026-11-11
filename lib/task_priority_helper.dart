import 'package:zero_trust_tasks/task_priority.dart';
import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

class TaskPriorityHelper {
  static String getDisplayName(TaskPriority priority) {
    if (priority == TaskPriority.critical) {
      return currentL10n.critical;
    } else if (priority == TaskPriority.high) {
      return currentL10n.high;
    } else if (priority == TaskPriority.medium) {
      return currentL10n.medium;
    } else {
      return currentL10n.low;
    }
  }

  static Color getColor(TaskPriority priority, BuildContext context) {
    if (priority == TaskPriority.critical) {
      return Colors.red;
    } else if (priority == TaskPriority.high) {
      return Colors.orange;
    } else if (priority == TaskPriority.medium) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }

  /// Icon used to distinguish priority levels without relying on color
  /// alone (accessibility for color-blind users).
  static IconData getIcon(TaskPriority priority) {
    if (priority == TaskPriority.critical) {
      return Icons.error;
    } else if (priority == TaskPriority.high) {
      return Icons.arrow_upward;
    } else if (priority == TaskPriority.medium) {
      return Icons.remove;
    } else {
      return Icons.arrow_downward;
    }
  }
}
