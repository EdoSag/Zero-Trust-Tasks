import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/storage/preference_keys.dart';

/// Tracks when the local data was last backed up to the cloud, and whether
/// the cloud copy is newer than that (item 4).
class SyncProvider extends ChangeNotifier {
  SyncProvider(this._prefs) {
    final stored = _prefs.getString(PreferenceKeys.lastSyncedAt);
    if (stored != null) {
      _lastSyncedAt = DateTime.tryParse(stored);
    }
  }

  factory SyncProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<SyncProvider>(context, listen: listen);
  }

  final SharedPreferences _prefs;

  DateTime? _lastSyncedAt;
  DateTime? _remoteUpdatedAt;
  bool _isChecking = false;

  /// When the local data was last backed up to (or restored from) the cloud.
  DateTime? get lastSyncedAt {
    return _lastSyncedAt;
  }

  /// The cloud copy's `updated_at`, last time it was checked.
  DateTime? get remoteUpdatedAt {
    return _remoteUpdatedAt;
  }

  bool get isChecking {
    return _isChecking;
  }

  /// Whether the cloud copy appears newer than the last local backup.
  bool get hasNewerRemoteData {
    if (_remoteUpdatedAt == null) {
      return false;
    }
    if (_lastSyncedAt == null) {
      return true;
    }
    return _remoteUpdatedAt!.isAfter(_lastSyncedAt!);
  }

  /// Marks the data as just backed up to / restored from the cloud.
  Future<void> markSynced({DateTime? at}) async {
    final timestamp = at ?? DateTime.now().toUtc();
    _lastSyncedAt = timestamp;
    _remoteUpdatedAt = timestamp;
    notifyListeners();
    await _prefs.setString(
      PreferenceKeys.lastSyncedAt,
      timestamp.toIso8601String(),
    );
  }

  /// Fetches the cloud copy's last-updated timestamp without downloading it.
  Future<void> checkRemoteStatus() async {
    if (SupabaseService.instance.currentUser == null) {
      return;
    }
    _isChecking = true;
    notifyListeners();
    try {
      _remoteUpdatedAt =
          await SupabaseService.instance.fetchEncryptedTasksMetadataForCurrentUser();
    } catch (_) {
      // Leave previous value; failures here are non-critical.
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}
