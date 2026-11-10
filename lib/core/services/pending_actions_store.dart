import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';

/// Holds Complete/Snooze taps from reminders and ticks from the home-screen
/// widget until the vault is open to apply them. Only task ids and times
/// are kept here, never titles.
///
/// Reminder buttons run in a background isolate, so this always re-reads
/// SharedPreferences from disk. Widget ticks are written by the widget's
/// own Android code into the home_widget preferences.
class PendingActionsStore {
  const PendingActionsStore();

  static const _key = 'pending_task_actions';

  /// Written by `TaskListWidgetProvider.kt`: task ids ticked on the widget,
  /// separated by newlines.
  static const widgetTicksKey = 'widget_pending_ticks';

  static bool get _widgetsSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> add(PendingTaskAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [...list, action.encode()]);
  }

  /// Everything queued, oldest first, and clears the queue.
  Future<List<PendingTaskAction>> takeAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getStringList(_key) ?? const [];
    if (raw.isNotEmpty) await prefs.remove(_key);
    final actions = [
      for (final r in raw)
        if (PendingTaskAction.tryParse(r) case final a?) a,
    ];
    if (_widgetsSupported) {
      try {
        final ticks = await HomeWidget.getWidgetData<String>(widgetTicksKey);
        if (ticks != null && ticks.trim().isNotEmpty) {
          await HomeWidget.saveWidgetData<String>(widgetTicksKey, null);
          for (final id in ticks.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
            actions.add(PendingTaskAction(type: PendingTaskActionType.complete, taskId: id, at: DateTime.now()));
          }
        }
      } on Object {
        // No widget support on this device: nothing to read.
      }
    }
    actions.sort((a, b) => a.at.compareTo(b.at));
    return actions;
  }
}
