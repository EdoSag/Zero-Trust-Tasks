import 'package:zero_trust_tasks/models/sync_conflict.dart';

/// Summary returned by [TaskManager.syncTasks].
class SyncResult {
  const SyncResult({
    required this.uploaded,
    required this.downloaded,
    this.conflicts = const [],
  });

  final int uploaded;
  final int downloaded;
  final List<SyncConflict> conflicts;

  bool get hadChanges => uploaded > 0 || downloaded > 0;
  bool get hasConflicts => conflicts.isNotEmpty;

  @override
  String toString() =>
      'SyncResult(uploaded: $uploaded, downloaded: $downloaded, '
      'conflicts: ${conflicts.length})';
}
