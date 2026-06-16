import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_trust_tasks/models/task.dart';

/// Manages local notifications for task reminders (item 20).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Whether task title/description should appear in notifications.
  /// Default false = privacy-preserving generic text.
  bool showTaskDetailsInNotifications = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
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

    final title = showTaskDetailsInNotifications ? task.title : 'Task reminder';
    final body = showTaskDetailsInNotifications
        ? (task.description ?? task.title)
        : 'You have a task reminder.';

    await _plugin.zonedSchedule(
      task.id.hashCode,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for your tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
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
