/// Summary returned by [TaskManager.syncTasks].
class SyncResult {
  const SyncResult({
    required this.uploaded,
    required this.downloaded,
  });

  final int uploaded;
  final int downloaded;

  bool get hadChanges => uploaded > 0 || downloaded > 0;

  @override
  String toString() => 'SyncResult(uploaded: $uploaded, downloaded: $downloaded)';
}
