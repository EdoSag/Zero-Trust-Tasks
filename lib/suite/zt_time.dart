import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// What ZT Time said when a task was handed to it.
enum TimeHandOver {
  /// Time saved the entry or started the timer.
  done,

  /// The person closed Time without saving.
  cancelled,

  /// ZT Time isn't installed (or this isn't Android).
  missing,
}

/// Hands a task to ZT Time (bz.zerotrust.action.TRACK_TIME, see
/// reports/zt-time-links.md). Without [start] and [end], Time offers to
/// start a timer for the task; with them, it opens "Add time" filled in
/// with that stretch. Time links the entry back to the task by its id and
/// opens it again with bz.zerotrust.action.OPEN_ITEM.
class ZtTime {
  const ZtTime._();

  static const _channel = MethodChannel('zt_tasks/time');
  static const package = 'dev.sagron.zerotrusttime';

  static Future<TimeHandOver> track(Task task, {DateTime? start, DateTime? end}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return TimeHandOver.missing;
    try {
      final answer = await _channel.invokeMethod<String>('track', {
        'id': task.id,
        'title': task.title,
        if (start != null && end != null) 'start': start.millisecondsSinceEpoch,
        if (start != null && end != null) 'end': end.millisecondsSinceEpoch,
      });
      return switch (answer) {
        'done' => TimeHandOver.done,
        'cancelled' => TimeHandOver.cancelled,
        _ => TimeHandOver.missing,
      };
    } on MissingPluginException {
      return TimeHandOver.missing;
    } on PlatformException {
      return TimeHandOver.missing;
    }
  }

  /// Where ZT Time is downloaded (GitHub releases, the suite's main channel).
  static Future<void> openDownloadPage() => launchUrl(
        Uri.parse('https://github.com/EdoSag/Zero-Trust-Time/releases/latest'),
        mode: LaunchMode.externalApplication,
      );
}

/// Minutes spent in Tasks' own focus timer on a task. A key in the task's
/// [Task.extra], so older versions keep it when they save the task.
extension TaskFocus on Task {
  static const key = 'focusMinutes';

  int get focusMinutes => extra[key] is num ? (extra[key] as num).toInt() : 0;

  Task withFocusMinutes(int minutes) => copyWith(extra: {...extra, key: minutes});
}
