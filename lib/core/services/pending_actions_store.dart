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

  /// Everything queued, oldest first. The queue keeps them until
  /// [acknowledge], so a lock or failed save mid-way loses nothing.
  Future<List<PendingTaskAction>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final actions = [
      for (final r in prefs.getStringList(_key) ?? const <String>[])
        if (PendingTaskAction.tryParse(r) case final a?) a,
    ];
    for (final id in await _widgetTicks()) {
      actions.add(PendingTaskAction(
        type: PendingTaskActionType.complete,
        taskId: id,
        at: DateTime.now(),
        fromWidget: true,
      ));
    }
    actions.sort((a, b) => a.at.compareTo(b.at));
    return actions;
  }

  /// Removes [done] from the queue. Taps added since [pending] stay.
  Future<void> acknowledge(List<PendingTaskAction> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final doneQueued = {for (final a in done) if (!a.fromWidget) a.encode()};
    final remaining = [
      for (final r in prefs.getStringList(_key) ?? const <String>[])
        if (!doneQueued.contains(PendingTaskAction.tryParse(r)?.encode())) r,
    ];
    if (remaining.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setStringList(_key, remaining);
    }
    final doneTicks = {for (final a in done) if (a.fromWidget) a.taskId};
    if (doneTicks.isNotEmpty && _widgetsSupported) {
      try {
        final left = (await _widgetTicks()).where((id) => !doneTicks.contains(id)).toList();
        await HomeWidget.saveWidgetData<String>(widgetTicksKey, left.isEmpty ? null : left.join('\n'));
      } on Object {
        // No widget support on this device.
      }
    }
  }

  Future<List<String>> _widgetTicks() async {
    if (!_widgetsSupported) return const [];
    try {
      final ticks = await HomeWidget.getWidgetData<String>(widgetTicksKey);
      return [
        for (final id in (ticks ?? '').split('\n').map((s) => s.trim()))
          if (id.isNotEmpty) id,
      ];
    } on Object {
      return const [];
    }
  }
}
