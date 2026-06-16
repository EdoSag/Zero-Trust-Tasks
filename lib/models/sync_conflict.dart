import 'package:zero_trust_tasks/models/task.dart';

/// A task where both the local copy and the remote copy changed since the last
/// sync — neither can be auto-resolved by last-writer-wins (item 36).
class SyncConflict {
  const SyncConflict({required this.local, required this.remote});

  final Task local;
  final Task remote;
}
