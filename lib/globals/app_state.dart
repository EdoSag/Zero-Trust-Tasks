import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/storage/preference_keys.dart';

@NowaGenerated()
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _themeMode = _readThemeMode();
  }

  factory AppState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<AppState>(context, listen: listen);
  }

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;

  ThemeMode get themeMode {
    return _themeMode;
  }

  ThemeMode _readThemeMode() {
    final raw = _prefs.getString(PreferenceKeys.themeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(PreferenceKeys.themeMode, raw);
  }
}
