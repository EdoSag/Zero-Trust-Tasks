import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

const _completeAction = 'complete';
const _snoozeAction = 'snooze';
const _iosCategory = 'task_reminder';

/// How long Snooze on a reminder waits.
const snoozeDuration = Duration(hours: 1);

AndroidNotificationDetails get _androidChannel => AndroidNotificationDetails(
  'task_reminders',
  currentL10n.taskReminders,
  channelDescription: currentL10n.remindersForYourTasks,
  importance: Importance.high,
  priority: Priority.high,
  actions: [
    AndroidNotificationAction(_completeAction, currentL10n.complete),
    AndroidNotificationAction(_snoozeAction, currentL10n.snooze1Hour),
  ],
);

NotificationDetails get _details => NotificationDetails(
  android: _androidChannel,
  iOS: const DarwinNotificationDetails(categoryIdentifier: _iosCategory),
);

/// Complete or Snooze tapped while the app isn't running. Runs in its own
/// isolate without the vault: it only notes the task id (applied at the
/// next unlock) and, for Snooze, shows the same reminder again later.
@pragma('vm:entry-point')
void notificationActionInBackground(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  unawaited(_handleAction(response, FlutterLocalNotificationsPlugin()));
}

Future<bool> _handleAction(NotificationResponse response, FlutterLocalNotificationsPlugin plugin) async {
  final actionId = response.actionId;
  if (actionId != _completeAction && actionId != _snoozeAction) return false;
  final payload = _ReminderPayload.tryParse(response.payload);
  if (payload == null) return false;
  final now = DateTime.now();
  if (actionId == _completeAction) {
    await const PendingActionsStore().add(
      PendingTaskAction(type: PendingTaskActionType.complete, taskId: payload.taskId, at: now),
    );
    await plugin.cancel(payload.notificationId);
  } else {
    final until = now.add(snoozeDuration);
    await const PendingActionsStore().add(
      PendingTaskAction(type: PendingTaskActionType.snooze, taskId: payload.taskId, until: until, at: now),
    );
    tz.initializeTimeZones();
    await plugin.zonedSchedule(
      payload.notificationId,
      payload.title,
      payload.body,
      tz.TZDateTime.from(until, tz.UTC),
      _details,
      payload: response.payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  return true;
}

/// What a reminder carries so its buttons work without the vault: the task
/// id and the text already on screen.
class _ReminderPayload {
  const _ReminderPayload(this.taskId, this.title, this.body);

  final String taskId;
  final String title;
  final String body;

  int get notificationId => taskId.hashCode;

  static _ReminderPayload? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _ReminderPayload(json['id'] as String, json['t'] as String? ?? '', json['b'] as String? ?? '');
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode({'id': taskId, 't': title, 'b': body});
}

/// Manages local notifications for task reminders, with Complete and
/// Snooze buttons.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final _actions = StreamController<void>.broadcast();

  /// Fires when a reminder button was tapped while the app is open, so the
  /// queued action can be applied at once.
  Stream<void> get actionQueued => _actions.stream;

  /// Whether task title/description should appear in notifications.
  /// Default false = privacy-preserving generic text.
  bool showTaskDetailsInNotifications = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _iosCategory,
          actions: [
            DarwinNotificationAction.plain(_completeAction, currentL10n.complete),
            DarwinNotificationAction.plain(_snoozeAction, currentL10n.snooze1Hour),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) async {
        if (await _handleAction(response, _plugin)) _actions.add(null);
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionInBackground,
    );
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Schedules a notification for [task.reminderAt]. No-op if no reminder set
  /// or the reminder time has already passed.
  Future<void> scheduleTaskReminder(Task task) async {
    if (!_initialized) await init();
    if (task.reminderAt == null) return;

    final scheduledTime = tz.TZDateTime.from(task.reminderAt!, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    final title = showTaskDetailsInNotifications ? task.title : currentL10n.taskReminder;
    final body = showTaskDetailsInNotifications
        ? (task.description ?? task.title)
        : currentL10n.youHaveATaskReminder;

    await _plugin.zonedSchedule(
      task.id.hashCode,
      title,
      body,
      scheduledTime,
      _details,
      payload: _ReminderPayload(task.id, title, body).encode(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(String taskId) async {
    if (!_initialized) await init();
    await _plugin.cancel(taskId.hashCode);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }
}
