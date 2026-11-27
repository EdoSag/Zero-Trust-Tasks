import 'package:zero_trust_tasks/core/services/quick_add_parser.dart';
import 'package:zt_assist/zt_assist.dart';

/// Puts ZT Assist's reading of a typed task together with the app's own.
///
/// The app's own reading ([own], from [QuickAddParser]) counts days exactly
/// but only knows the phrases it was taught. ZT Assist ([read]) understands
/// free wording ("half past four in the afternoon", "remind me an hour
/// before") but is a small model that can slip. So:
///  * the day is the app's own where the text named one, else ZT Assist's;
///    a repeat that falls on today starts today, or a week on when the
///    time, whoever read it, has passed;
///  * the title, the time and the length are ZT Assist's where it has one,
///    else the app's own;
///  * the reminder comes from ZT Assist only;
///  * repeats, priority and tags stay the app's own.
///
/// The result is shown in the sheet before the task is added.
QuickAdd mergeAssistReading(QuickAdd own, ZtAssistQuickAdd read, {required DateTime now}) {
  final ownDue = own.due;
  var due = ownDue;
  var hasTime = own.hasTime;
  var hasDate = own.hasDate;

  if (read.day != null || read.hasTime) {
    final today = DateTime(now.year, now.month, now.day);
    // The app moved a repeat that falls on today a week on where its own
    // time had passed. The time may be another one now, so start over from
    // today.
    var day = own.repeatStartsToday
        ? today
        : own.hasDate && ownDue != null
        ? DateTime(ownDue.year, ownDue.month, ownDue.day)
        : read.day;
    final hour = read.hour ?? (own.hasTime ? ownDue!.hour : null);
    final minute = read.minute ?? (own.hasTime ? ownDue!.minute : null);
    hasDate = day != null;
    if (hour == null || minute == null) {
      // A day with no time. `day` is set: the time was not, so the day was.
      due = day;
      hasTime = false;
    } else {
      if (day == null) {
        // Only a time: today, or tomorrow when that time has passed. The
        // same rule as the app's own reading.
        final today = DateTime(now.year, now.month, now.day, hour, minute);
        day = today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1);
      }
      due = DateTime(day.year, day.month, day.day, hour, minute);
      // "every thursday at 9" typed on Thursday at 10 starts next Thursday.
      if (own.repeatStartsToday && !due.isAfter(now)) {
        due = DateTime(day.year, day.month, day.day + 7, hour, minute);
      }
      hasTime = true;
    }
  }

  // "Remind me an hour before" needs a time to count back from.
  final before = read.remindMinutesBefore;
  final reminderAt = before != null && before > 0 && hasTime && due != null
      ? due.subtract(Duration(minutes: before))
      : null;

  return QuickAdd(
    title: _title(read.title, own) ?? own.title,
    due: due,
    hasTime: hasTime,
    hasDate: hasDate,
    repeatStartsToday: own.repeatStartsToday,
    reminderAt: reminderAt,
    recurrence: own.recurrence,
    priority: own.priority,
    tags: own.tags,
    minutes: read.lengthMinutes ?? own.minutes,
  );
}

/// ZT Assist's title without the `#tags` and the `!priority` the app has
/// already read out of the text.
String? _title(String? title, QuickAdd own) {
  if (title == null) return null;
  var text = title;
  if (own.tags.isNotEmpty) {
    text = text.replaceAll(RegExp(r'(?<!\S)#[\p{L}\p{N}_-]+', unicode: true), ' ');
  }
  if (own.priority != null) {
    text = text.replaceAll(RegExp(r'(?<!\S)![\p{L}]+', unicode: true), ' ');
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.isEmpty ? null : text;
}
