import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/storage/preference_keys.dart';
import 'package:zero_trust_tasks/encryption_service.dart';

enum AutoLockDuration { immediately, oneMinute, fiveMinutes, fifteenMinutes, never }

extension AutoLockDurationExtension on AutoLockDuration {
  String get displayName {
    switch (this) {
      case AutoLockDuration.immediately:
        return 'Immediately';
      case AutoLockDuration.oneMinute:
        return '1 min';
      case AutoLockDuration.fiveMinutes:
        return '5 min';
      case AutoLockDuration.fifteenMinutes:
        return '15 min';
      case AutoLockDuration.never:
        return 'Never';
    }
  }

  Duration? get duration {
    switch (this) {
      case AutoLockDuration.immediately:
        return Duration.zero;
      case AutoLockDuration.oneMinute:
        return const Duration(minutes: 1);
      case AutoLockDuration.fiveMinutes:
        return const Duration(minutes: 5);
      case AutoLockDuration.fifteenMinutes:
        return const Duration(minutes: 15);
      case AutoLockDuration.never:
        return null;
    }
  }

  static AutoLockDuration fromKey(String key) {
    return AutoLockDuration.values.firstWhere(
      (d) => d.name == key,
      orElse: () => AutoLockDuration.never,
    );
  }
}

/// Manages the app lock state and auto-lock duration preference (item 23).
class LockProvider extends ChangeNotifier {
  LockProvider(this._prefs) {
    final stored = _prefs.getString(PreferenceKeys.autoLockDuration);
    if (stored != null) {
      _autoLockDuration = AutoLockDurationExtension.fromKey(stored);
    }
  }

  factory LockProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<LockProvider>(context, listen: listen);
  }

  final SharedPreferences _prefs;

  bool _isLocked = false;
  AutoLockDuration _autoLockDuration = AutoLockDuration.never;

  bool get isLocked => _isLocked;
  AutoLockDuration get autoLockDuration => _autoLockDuration;

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    if (_autoLockDuration == duration) return;
    _autoLockDuration = duration;
    notifyListeners();
    await _prefs.setString(PreferenceKeys.autoLockDuration, duration.name);
  }

  /// Locks the app and clears the encryption session key from memory.
  void lock() {
    EncryptionService.clearSessionKey();
    _isLocked = true;
    notifyListeners();
  }

  /// Called after successful password/biometric re-authentication.
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
}
