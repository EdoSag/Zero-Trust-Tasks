/// How the user wants to resolve a sync conflict (item 36).
enum ConflictResolution {
  /// Keep the local version, overwrite the remote.
  keepLocal,

  /// Accept the remote version, replace the local copy.
  keepRemote,

  /// Keep both: local stays as-is, remote is saved as a new duplicate task.
  keepBoth,
}
