import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_helper.dart';

extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    return TaskPriorityHelper.getDisplayName(this);
  }

  Color getColor(BuildContext context) {
    return TaskPriorityHelper.getColor(this, context);
  }

  IconData get icon {
    return TaskPriorityHelper.getIcon(this);
  }
}
