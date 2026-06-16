import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/storage/preference_keys.dart';

/// Holds non-sensitive app/UI preferences that are persisted locally via
/// SharedPreferences (theme mode, last selected tab, task list filter/sort
/// state, etc).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _lastSelectedTab = _prefs.getInt(PreferenceKeys.lastSelectedTab) ?? 0;
    _taskSectionsCollapsed =
        _prefs.getBool(PreferenceKeys.taskSectionsCollapsed) ?? false;
    _taskFilterStateJson = _prefs.getString(PreferenceKeys.taskFilterState);
    _showTaskDetailsInNotifications = _prefs.getBool(
          PreferenceKeys.showTaskDetailsInNotifications,
        ) ??
        false;
    NotificationService.instance.showTaskDetailsInNotifications =
        _showTaskDetailsInNotifications;
  }

  factory SettingsProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<SettingsProvider>(context, listen: listen);
  }

  final SharedPreferences _prefs;

  late int _lastSelectedTab;
  late bool _taskSectionsCollapsed;
  String? _taskFilterStateJson;
  late bool _showTaskDetailsInNotifications;

  int get lastSelectedTab {
    return _lastSelectedTab;
  }

  bool get taskSectionsCollapsed {
    return _taskSectionsCollapsed;
  }

  /// Raw JSON string of the persisted [TaskFilterState], if any.
  String? get taskFilterStateJson {
    return _taskFilterStateJson;
  }

  bool get showTaskDetailsInNotifications {
    return _showTaskDetailsInNotifications;
  }

  Future<void> setLastSelectedTab(int index) async {
    if (_lastSelectedTab == index) {
      return;
    }
    _lastSelectedTab = index;
    notifyListeners();
    await _prefs.setInt(PreferenceKeys.lastSelectedTab, index);
  }

  Future<void> setTaskSectionsCollapsed(bool collapsed) async {
    if (_taskSectionsCollapsed == collapsed) {
      return;
    }
    _taskSectionsCollapsed = collapsed;
    notifyListeners();
    await _prefs.setBool(PreferenceKeys.taskSectionsCollapsed, collapsed);
  }

  Future<void> setTaskFilterStateJson(String? json) async {
    _taskFilterStateJson = json;
    if (json == null) {
      await _prefs.remove(PreferenceKeys.taskFilterState);
    } else {
      await _prefs.setString(PreferenceKeys.taskFilterState, json);
    }
  }

  Future<void> setShowTaskDetailsInNotifications(bool value) async {
    if (_showTaskDetailsInNotifications == value) return;
    _showTaskDetailsInNotifications = value;
    NotificationService.instance.showTaskDetailsInNotifications = value;
    notifyListeners();
    await _prefs.setBool(
      PreferenceKeys.showTaskDetailsInNotifications,
      value,
    );
  }
}
