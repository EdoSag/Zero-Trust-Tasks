import 'package:zero_trust_tasks/l10n/l10n.dart';
enum TaskSortOption { dueDateAsc, dueDateDesc, priority, createdDate, alphabetical, manual }

extension TaskSortOptionExtension on TaskSortOption {
  String get displayName {
    switch (this) {
      case TaskSortOption.dueDateAsc:
        return currentL10n.dueDateEarliestFirst;
      case TaskSortOption.dueDateDesc:
        return currentL10n.dueDateLatestFirst;
      case TaskSortOption.priority:
        return currentL10n.priority;
      case TaskSortOption.createdDate:
        return currentL10n.dateCreated;
      case TaskSortOption.alphabetical:
        return currentL10n.alphabetical;
      case TaskSortOption.manual:
        return currentL10n.myOrderDragToReorder;
    }
  }
}
