import 'package:flutter/material.dart';
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

  final SharedPreferences _prefs;

  /// Which tasks the Tasks tab shows: `all`, `starred` or `list:<id>`.
  String get taskListScope => _prefs.getString(PreferenceKeys.taskListScope) ?? 'all';

  Future<void> setTaskListScope(String value) async {
    await _prefs.setString(PreferenceKeys.taskListScope, value);
    notifyListeners();
  }

  /// Whether the home-screen widget shows task titles (stored unencrypted
  /// by the launcher). Off: counts only.
  bool get widgetShowTasks => _prefs.getBool(PreferenceKeys.widgetShowTasks) ?? false;

  Future<void> setWidgetShowTasks(bool value) async {
    await _prefs.setBool(PreferenceKeys.widgetShowTasks, value);
    notifyListeners();
  }

  /// The list the widget shows; null shows every list.
  String? get widgetListId => _prefs.getString(PreferenceKeys.widgetListId);

  Future<void> setWidgetListId(String? id) async {
    if (id == null) {
      await _prefs.remove(PreferenceKeys.widgetListId);
    } else {
      await _prefs.setString(PreferenceKeys.widgetListId, id);
    }
    notifyListeners();
  }

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
