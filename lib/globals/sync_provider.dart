import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/storage/preference_keys.dart';

enum AutoBackupFrequency { off, daily, weekly }

extension AutoBackupFrequencyExtension on AutoBackupFrequency {
  String get displayName {
    switch (this) {
      case AutoBackupFrequency.off:
        return 'Off';
      case AutoBackupFrequency.daily:
        return 'Daily';
      case AutoBackupFrequency.weekly:
        return 'Weekly';
    }
  }

  String get _key {
    return name;
  }

  static AutoBackupFrequency fromKey(String key) {
    return AutoBackupFrequency.values.firstWhere(
      (f) => f.name == key,
      orElse: () => AutoBackupFrequency.off,
    );
  }
}

/// Tracks sync state (last backup time, remote status) and auto-backup
/// frequency preference (items 4, 22).
class SyncProvider extends ChangeNotifier {
  SyncProvider(this._prefs) {
    final storedSyncedAt = _prefs.getString(PreferenceKeys.lastSyncedAt);
    if (storedSyncedAt != null) {
      _lastSyncedAt = DateTime.tryParse(storedSyncedAt);
    }
    final storedFreq = _prefs.getString(PreferenceKeys.autoBackupFrequency);
    if (storedFreq != null) {
      _autoBackupFrequency = AutoBackupFrequencyExtension.fromKey(storedFreq);
    }
    _autoSyncEnabled =
        _prefs.getBool(PreferenceKeys.autoSyncEnabled) ?? false;
  }

  factory SyncProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<SyncProvider>(context, listen: listen);
  }

  final SharedPreferences _prefs;

  DateTime? _lastSyncedAt;
  DateTime? _remoteUpdatedAt;
  bool _isChecking = false;
  bool _isSyncing = false;
  AutoBackupFrequency _autoBackupFrequency = AutoBackupFrequency.off;
  bool _autoSyncEnabled = false;

  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get remoteUpdatedAt => _remoteUpdatedAt;
  bool get isChecking => _isChecking;
  bool get isSyncing => _isSyncing;
  AutoBackupFrequency get autoBackupFrequency => _autoBackupFrequency;
  bool get autoSyncEnabled => _autoSyncEnabled;

  void setSyncing(bool value) {
    if (_isSyncing == value) return;
    _isSyncing = value;
    notifyListeners();
  }

  bool get hasNewerRemoteData {
    if (_remoteUpdatedAt == null) return false;
    if (_lastSyncedAt == null) return true;
    return _remoteUpdatedAt!.isAfter(_lastSyncedAt!);
  }

  Future<void> setAutoBackupFrequency(AutoBackupFrequency frequency) async {
    if (_autoBackupFrequency == frequency) return;
    _autoBackupFrequency = frequency;
    notifyListeners();
    await _prefs.setString(
      PreferenceKeys.autoBackupFrequency,
      frequency._key,
    );
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    if (_autoSyncEnabled == value) return;
    _autoSyncEnabled = value;
    notifyListeners();
    await _prefs.setBool(PreferenceKeys.autoSyncEnabled, value);
  }

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

  Future<void> checkRemoteStatus() async {
    if (SupabaseService.instance.currentUser == null) return;
    _isChecking = true;
    notifyListeners();
    try {
      _remoteUpdatedAt = await SupabaseService.instance
          .fetchEncryptedTasksMetadataForCurrentUser();
    } catch (_) {
      // Non-critical; leave previous value.
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}
