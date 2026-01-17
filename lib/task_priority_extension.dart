import 'package:nowa_runtime/nowa_runtime.dart';

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
