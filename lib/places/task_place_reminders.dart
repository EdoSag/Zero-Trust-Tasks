import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/app/tasks_hooks.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zt_places/zt_places.dart';

/// "Remind me when I arrive at / leave a place" for one task (T11).
///
/// Kept as its own item in the account's encrypted vault, never inside the
/// task: a task in a shared list would otherwise carry this person's places
/// to everyone in the list. The phone itself watches the place (Android's
/// LocationManager via `zt_places`), so the location never leaves it.
class TaskPlaceReminder {
  const TaskPlaceReminder({required this.taskId, required this.place, required this.trigger, required this.armedAt});

  final String taskId;
  final ZtPlace place;
  final ZtPlaceTrigger trigger;

  /// When it was set. Part of the alert id: an alert fires once, and
  /// setting it again (a new time) arms it again.
  final DateTime armedAt;

  static String itemIdFor(String taskId) => 'place_reminder/$taskId';

  String get alertId => '$taskId@${armedAt.millisecondsSinceEpoch}';

  static TaskPlaceReminder? fromJson(Map<String, Object?> json) {
    final place = ZtPlace.fromJson(json['place']);
    final taskId = json['taskId'];
    if (place == null || taskId is! String) return null;
    return TaskPlaceReminder(
      taskId: taskId,
      place: place,
      trigger: ZtPlaceTrigger.parse(json['trigger']),
      armedAt: DateTime.tryParse(json['armedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'place': place.toJson(),
    'trigger': trigger.name,
    'armedAt': armedAt.toUtc().toIso8601String(),
  };
}

final placeRemindersCollection = ZtCollection<TaskPlaceReminder>(
  kind: 'place_reminder',
  fromJson: (_, json, _) => TaskPlaceReminder.fromJson(json) ?? (throw const FormatException('bad place reminder')),
  toJson: (r) => r.toJson(),
  idOf: (r) => TaskPlaceReminder.itemIdFor(r.taskId),
);

/// "My places", offered again by the picker.
final savedPlacesCollection = ZtCollection<ZtPlace>(
  kind: 'place',
  fromJson: (_, json, _) => ZtPlace.fromJson(json) ?? (throw const FormatException('bad place')),
  toJson: (p) => p.toJson(),
  idOf: (p) => 'place/${p.id}',
);

/// The phone's place watcher. A do-nothing fake while platform hooks are
/// off (widget tests).
final ztPlaceRemindersProvider = Provider<ZtPlaceReminders>((ref) {
  if (!ref.watch(platformHooksEnabledProvider)) return ZtPlaceRemindersFake(supported: false);
  return ZtPlaceRemindersAndroid();
});

class PlaceRemindersState {
  const PlaceRemindersState({this.reminders = const {}, this.places = const []});
  final Map<String, TaskPlaceReminder> reminders;
  final List<ZtPlace> places;
  TaskPlaceReminder? forTask(String taskId) => reminders[taskId];
}

/// Keeps the phone's place alerts in step with the tasks: an alert for each
/// open task with a place reminder, none for done or deleted ones.
class PlaceRemindersController extends Notifier<PlaceRemindersState> {
  ZtLocalStore? _store;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _debounce;
  String? _lastArmed;
  bool _armedOnce = false;
  bool _loaded = false;

  /// Alert ids that fired while the vault was locked, to forget on unlock.
  static const firedKey = 'place_reminders_fired';

  ZtPlaceReminders get _phone => ref.read(ztPlaceRemindersProvider);

  @override
  PlaceRemindersState build() {
    final store = ref.watch(tasksStoreProvider);
    _store = store;
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _debounce?.cancel();
    });
    _loaded = false;
    if (store == null) return const PlaceRemindersState();
    _subs.add(
      placeRemindersCollection.watch(store).listen((list) {
        _loaded = true;
        state = PlaceRemindersState(reminders: {for (final r in list) r.taskId: r}, places: state.places);
        _schedule();
      }, onError: (Object _) {}),
    );
    _subs.add(
      savedPlacesCollection.watch(store).listen((list) {
        state = PlaceRemindersState(
          reminders: state.reminders,
          places: list..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        );
      }, onError: (Object _) {}),
    );
    ref.listen(taskManagerProvider, (_, _) => _schedule());
    return const PlaceRemindersState();
  }

  Future<SyncController> _sync() async {
    await ref.read(ztSyncEngineProvider.future);
    return ref.read(ztSyncControllerProvider.notifier);
  }

  ZtLocalStore get _requireStore => _store ?? (throw StateError('Your tasks are locked.'));

  /// Sets (or replaces) [taskId]'s place reminder. [saveToPlaces] keeps the
  /// place under "My places" too.
  Future<void> set(String taskId, ZtPlace place, ZtPlaceTrigger trigger, {bool saveToPlaces = false}) async {
    final store = _requireStore;
    final sync = await _sync();
    final reminder = TaskPlaceReminder(taskId: taskId, place: place, trigger: trigger, armedAt: DateTime.now().toUtc());
    state = PlaceRemindersState(reminders: {...state.reminders, taskId: reminder}, places: state.places);
    await placeRemindersCollection.save(sync, store, reminder);
    if (saveToPlaces) await savedPlacesCollection.save(sync, store, place);
    _schedule();
  }

  Future<void> remove(String taskId) async {
    if (!state.reminders.containsKey(taskId)) return;
    final sync = await _sync();
    state = PlaceRemindersState(reminders: {...state.reminders}..remove(taskId), places: state.places);
    await placeRemindersCollection.delete(sync, TaskPlaceReminder.itemIdFor(taskId));
    _schedule();
  }

  Future<void> removePlace(ZtPlace place) async {
    final sync = await _sync();
    state = PlaceRemindersState(
      reminders: state.reminders,
      places: state.places.where((p) => p.id != place.id).toList(),
    );
    await savedPlacesCollection.delete(sync, 'place/${place.id}');
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => unawaited(arm()));
  }

  /// The alerts the phone should watch now.
  @visibleForTesting
  List<ZtPlaceReminder> wanted() {
    final manager = ref.read(taskManagerProvider);
    final byId = {for (final t in manager.tasks) t.id: t};
    final showTitle = NotificationService.instance.showTaskDetailsInNotifications;
    return [
      for (final r in state.reminders.values)
        if (byId[r.taskId] case final Task t when t.deletedAt == null && !t.isCompleted && !t.isArchived)
          ZtPlaceReminder(
            id: r.alertId,
            place: r.place,
            trigger: r.trigger,
            title: showTitle ? t.title : currentL10n.taskReminder,
            body: r.place.name.isEmpty
                ? ''
                : (r.trigger == ZtPlaceTrigger.arrive
                      ? currentL10n.arrivedAt(r.place.name)
                      : currentL10n.leftPlace(r.place.name)),
            payload: t.id,
          ),
    ];
  }

  /// Hands the phone the current alerts, once the tasks (shared lists
  /// included) have been read, so a half-read list never cancels any.
  Future<void> arm() async {
    if (_store == null || !_loaded) return;
    final manager = ref.read(taskManagerProvider);
    if (manager.isLoading || !manager.sharedReady) return;
    if (state.reminders.isEmpty && !_armedOnce) {
      // Nothing set on this account: clear whatever an earlier sign-in
      // left armed, once.
      _armedOnce = true;
      _lastArmed = '';
      try {
        await _phone.sync(const [], style: _style);
      } on Object {
        // no place support on this phone
      }
      return;
    }
    // Reminders of tasks deleted for good (or of a shared list left) go.
    final ids = {for (final t in manager.tasks) t.id};
    for (final r in state.reminders.values.toList()) {
      if (!ids.contains(r.taskId)) unawaited(remove(r.taskId).catchError((Object _) {}));
    }
    final alerts = wanted();
    final key = [for (final r in alerts) '${r.id}|${r.title}|${r.body}'].join('\n');
    if (key == _lastArmed) return;
    _lastArmed = key;
    _armedOnce = true;
    try {
      await _phone.sync(alerts, style: _style);
    } on Object catch (e) {
      debugPrint('Place reminders not armed: $e');
    }
  }

  ZtPlaceNotificationStyle get _style => ZtPlaceNotificationStyle(
    channelId: 'zt_tasks_place_reminders',
    channelName: currentL10n.placeRemindersChannel,
    channelDescription: currentL10n.placeRemindersChannelHint,
    smallIcon: 'ic_zt_widget_check',
    doneLabel: currentL10n.complete,
    publicTitle: currentL10n.taskReminder,
  );

  /// Acts on what happened to alerts: a fired one is used up, "Done" ticks
  /// the task (queued like a reminder's Complete button, so it is applied
  /// even while locked).
  Future<void> handle(ZtPlaceEvent e) async {
    switch (e.type) {
      case ZtPlaceEventType.fired:
        await _forgetFired(e.reminderId);
      case ZtPlaceEventType.done:
        await const PendingActionsStore().add(
          PendingTaskAction(type: PendingTaskActionType.complete, taskId: e.payload, at: DateTime.now()),
        );
        await _forgetFired(e.reminderId);
      case ZtPlaceEventType.tap:
        await _forgetFired(e.reminderId);
    }
  }

  Future<void> _forgetFired(String alertId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final store = _store;
    if (store == null) {
      // Locked: remember the id (no title, no place) until unlock.
      await prefs.setStringList(firedKey, {...?prefs.getStringList(firedKey), alertId}.toList());
      return;
    }
    final ids = {...?prefs.getStringList(firedKey), alertId};
    for (final r in state.reminders.values.toList()) {
      if (ids.contains(r.alertId)) await remove(r.taskId);
    }
    await prefs.remove(firedKey);
  }

  /// After unlock: alerts that fired while the vault was locked.
  Future<void> forgetFiredWhileLocked() async {
    final ids = ref.read(sharedPreferencesProvider).getStringList(firedKey);
    if (ids == null || ids.isEmpty) return;
    await _forgetFired(ids.first);
  }

  /// Signed out: the phone stops watching every place.
  Future<void> clearPhone() async {
    _lastArmed = null;
    _armedOnce = false;
    try {
      await _phone.clear();
    } on Object {
      // nothing armed
    }
  }
}

final placeRemindersProvider = NotifierProvider<PlaceRemindersController, PlaceRemindersState>(
  PlaceRemindersController.new,
);
