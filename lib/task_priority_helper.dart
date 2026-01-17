import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:flutter/material.dart';

@NowaGenerated()
class TaskPriorityHelper {
  static String getDisplayName(TaskPriority priority) {
    if (priority == TaskPriority.critical) {
      return 'Critical';
    } else if (priority == TaskPriority.high) {
      return 'High';
    } else if (priority == TaskPriority.medium) {
      return 'Medium';
    } else {
      return 'Low';
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
}
