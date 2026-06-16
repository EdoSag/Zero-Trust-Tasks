/// Summary of what applying a backup would change (item 25).
class BackupPreview {
  const BackupPreview({
    required this.backupTaskCount,
    required this.toAdd,
    required this.toUpdate,
    required this.toRemove,
  });

  /// Total number of tasks in the backup.
  final int backupTaskCount;

  /// Tasks in the backup that do not exist locally (will be added).
  final int toAdd;

  /// Tasks that exist in both but differ (will be updated).
  final int toUpdate;

  /// Local tasks not present in the backup (will be removed).
  final int toRemove;

  bool get hasChanges => toAdd > 0 || toUpdate > 0 || toRemove > 0;
}
