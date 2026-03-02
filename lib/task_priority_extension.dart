import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_helper.dart';

@NowaGenerated()
extension TaskPriorityExtension on TaskPriority {
  @NowaGenerated()
  String get displayName {
    return TaskPriorityHelper.getDisplayName(this);
  }

  @NowaGenerated()
  Color getColor(BuildContext context) {
    return TaskPriorityHelper.getColor(this, context);
  }
}
