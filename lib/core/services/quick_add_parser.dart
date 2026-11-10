import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/task_priority.dart';

/// What a line like "call mum tomorrow 6pm !high #family" means.
class QuickAdd {
  const QuickAdd({
    required this.title,
    this.due,
    this.hasTime = false,
    this.recurrence,
    this.priority,
    this.tags = const [],
  });

  /// The text with every recognised date, time, repeat, priority and tag
  /// taken out.
  final String title;

  /// Due date; at midnight when [hasTime] is false.
  final DateTime? due;
  final bool hasTime;
  final RecurrenceRule? recurrence;
  final TaskPriority? priority;
  final List<String> tags;

  bool get isEmpty => title.isEmpty;
}

/// Reads dates and times out of a typed task, in English and Hebrew.
/// Everything happens on the device; nothing is sent anywhere.
///
/// Understood (English): today, tonight, tomorrow, day after tomorrow,
/// weekday names ("fri", "next monday"), "in 3 days / 2 weeks / 4 hours",
/// "next week / month", dates ("12/5", "12.5.2027", "may 12", "12 may"),
/// times ("6pm", "6:30 pm", "18:00", "at 6", noon, midnight, morning,
/// afternoon, evening), repeats ("every day", "weekly", "every 2 weeks"),
/// priority ("!high", "!low", "!urgent") and tags ("#home").
///
/// Hebrew: היום, הערב, מחר, מחרתיים, יום ראשון … שבת (with ב), בעוד 3 ימים,
/// שבוע הבא, בשעה 18:00 / ב-18:00, בבוקר, בצהריים, אחר הצהריים, בערב,
/// כל יום / שבוע / חודש / שנה.
///
/// Numeric dates are read day first (12/5 is 12 May) unless that can't be
/// a date.
class QuickAddParser {
  const QuickAddParser._();

  // Not preceded / followed by a letter or digit. `\b` only knows ASCII, so
  // it would not work for Hebrew.
  static const _s = r'(?<![\p{L}\p{N}])';
  static const _e = r'(?![\p{L}\p{N}])';

  static RegExp _re(String body) => RegExp('$_s(?:$body)$_e', caseSensitive: false, unicode: true);

  static const _weekdaysEn = {
    'monday': 1, 'mon': 1, 'tuesday': 2, 'tue': 2, 'tues': 2, 'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4, 'friday': 5, 'fri': 5, 'saturday': 6,
    'sat': 6, 'sunday': 7, 'sun': 7,
  };
  static const _weekdaysHe = {
    'ראשון': 7, 'שני': 1, 'שלישי': 2, 'רביעי': 3, 'חמישי': 4, 'שישי': 5, 'שבת': 6,
  };
  static const _months = {
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3, 'april': 4,
    'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'october': 10, 'oct': 10, 'november': 11,
    'nov': 11, 'december': 12, 'dec': 12,
  };
  static const _unitsEn = {
    'minute': 'min', 'minutes': 'min', 'min': 'min', 'mins': 'min', 'hour': 'h', 'hours': 'h',
    'hr': 'h', 'hrs': 'h', 'day': 'd', 'days': 'd', 'week': 'w', 'weeks': 'w', 'month': 'm',
    'months': 'm',
  };
  static const _unitsHe = {
    'דקה': 'min', 'דקות': 'min', 'שעה': 'h', 'שעות': 'h', 'יום': 'd', 'ימים': 'd',
    'שבוע': 'w', 'שבועות': 'w', 'חודש': 'm', 'חודשים': 'm',
  };
  // "in two hours" as single words: שעתיים, יומיים, שבועיים, חודשיים.
  static const _dualHe = {'שעתיים': 'h', 'יומיים': 'd', 'שבועיים': 'w', 'חודשיים': 'm'};
  static const _priorities = {
    'low': TaskPriority.low, 'medium': TaskPriority.medium, 'med': TaskPriority.medium,
    'high': TaskPriority.high, 'critical': TaskPriority.critical, 'urgent': TaskPriority.critical,
    'נמוך': TaskPriority.low, 'בינוני': TaskPriority.medium, 'גבוה': TaskPriority.high,
    'דחוף': TaskPriority.critical,
  };
  static const _freqEn = {
    'day': RecurrenceFrequency.daily, 'days': RecurrenceFrequency.daily,
    'week': RecurrenceFrequency.weekly, 'weeks': RecurrenceFrequency.weekly,
    'month': RecurrenceFrequency.monthly, 'months': RecurrenceFrequency.monthly,
    'year': RecurrenceFrequency.yearly, 'years': RecurrenceFrequency.yearly,
    'daily': RecurrenceFrequency.daily, 'weekly': RecurrenceFrequency.weekly,
    'monthly': RecurrenceFrequency.monthly, 'yearly': RecurrenceFrequency.yearly,
    'annually': RecurrenceFrequency.yearly,
  };
  static const _freqHe = {
    'יום': RecurrenceFrequency.daily, 'שבוע': RecurrenceFrequency.weekly,
    'חודש': RecurrenceFrequency.monthly, 'שנה': RecurrenceFrequency.yearly,
  };

  static String _alt(Iterable<String> words) =>
      (words.toList()..sort((a, b) => b.length - a.length)).map(RegExp.escape).join('|');

  static QuickAdd parse(String input, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    var text = input;
    DateTime? date;
    int? hour;
    int? minute;
    Duration? offset; // "in 2 hours": a moment, not a day
    RecurrenceRule? recurrence;
    TaskPriority? priority;
    final tags = <String>[];

    /// Runs [pattern]; when [use] accepts the first match, removes it.
    void take(RegExp pattern, bool Function(RegExpMatch m) use) {
      for (final m in pattern.allMatches(text)) {
        if (use(m)) {
          text = '${text.substring(0, m.start)} ${text.substring(m.end)}';
          return;
        }
      }
    }

    DateTime addMonths(DateTime d, int months) {
      final first = DateTime(d.year, d.month + months, 1);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, d.day > lastDay ? lastDay : d.day);
    }

    /// Days until the coming [weekday] (1 to 7; never today).
    int daysUntil(int weekday) {
      final days = (weekday - today.weekday) % 7;
      return days == 0 ? 7 : days;
    }

    DateTime inDays(int days) => DateTime(today.year, today.month, today.day + days);
    DateTime nextWeekday(int weekday) => inDays(daysUntil(weekday));

    bool setDate(DateTime d) {
      if (date != null) return false;
      date = d;
      return true;
    }

    bool setTime(int h, int m) {
      if (hour != null || h > 23 || m > 59) return false;
      hour = h;
      minute = m;
      return true;
    }

    // Tags and priority first: they can't be mistaken for anything else.
    for (final m in RegExp(r'(?<!\S)#([\p{L}\p{N}_-]+)', unicode: true).allMatches(text)) {
      tags.add(m.group(1)!);
    }
    text = text.replaceAll(RegExp(r'(?<!\S)#[\p{L}\p{N}_-]+', unicode: true), ' ');
    take(RegExp('(?<!\\S)!(${_alt(_priorities.keys)})$_e', caseSensitive: false, unicode: true), (m) {
      priority = _priorities[m.group(1)!.toLowerCase()];
      return true;
    });

    // Repeats.
    take(_re('every\\s+(?:(\\d{1,2})\\s+)?(day|days|week|weeks|month|months|year|years)'), (m) {
      recurrence = RecurrenceRule(
        frequency: _freqEn[m.group(2)!.toLowerCase()]!,
        interval: int.tryParse(m.group(1) ?? '') ?? 1,
      );
      return true;
    });
    if (recurrence == null) {
      take(_re('daily|weekly|monthly|yearly|annually'), (m) {
        recurrence = RecurrenceRule(frequency: _freqEn[m.group(0)!.toLowerCase()]!);
        return true;
      });
    }
    if (recurrence == null) {
      take(_re('every\\s+(${_alt(_weekdaysEn.keys)})'), (m) {
        final weekday = _weekdaysEn[m.group(1)!.toLowerCase()]!;
        recurrence = RecurrenceRule(frequency: RecurrenceFrequency.weekly, weekdays: [weekday]);
        setDate(today.weekday == weekday ? today : nextWeekday(weekday));
        return true;
      });
    }
    if (recurrence == null) {
      take(_re('כל\\s+יום\\s+(${_alt(_weekdaysHe.keys)})|כל\\s+(שבת)'), (m) {
        final weekday = _weekdaysHe[m.group(1) ?? m.group(2)!]!;
        recurrence = RecurrenceRule(frequency: RecurrenceFrequency.weekly, weekdays: [weekday]);
        setDate(today.weekday == weekday ? today : nextWeekday(weekday));
        return true;
      });
    }
    if (recurrence == null) {
      take(_re('כל\\s+(${_alt(_freqHe.keys)})'), (m) {
        recurrence = RecurrenceRule(frequency: _freqHe[m.group(1)!]!);
        return true;
      });
    }

    // "in 3 days", "בעוד שעתיים".
    take(_re('in\\s+(\\d{1,3}|an?)\\s+(${_alt(_unitsEn.keys)})'), (m) {
      final n = int.tryParse(m.group(1)!) ?? 1;
      return _applyOffset(_unitsEn[m.group(2)!.toLowerCase()]!, n, today, addMonths, setDate, (d) => offset = d);
    });
    take(_re('(?:בעוד|עוד)\\s+(?:(\\d{1,3})\\s+)?(${_alt([..._unitsHe.keys, ..._dualHe.keys])})'), (m) {
      final word = m.group(2)!;
      final dual = _dualHe[word];
      final n = dual != null ? 2 : (int.tryParse(m.group(1) ?? '') ?? 1);
      return _applyOffset(dual ?? _unitsHe[word]!, n, today, addMonths, setDate, (d) => offset = d);
    });

    // "tomorrow morning": a part of the day only counts next to a day (or
    // with "in the" / "this", below), so "morning run" keeps its title.
    const parts = {'morning': 9, 'afternoon': 15, 'evening': 19, 'night': 21};
    take(_re('(today|tomorrow)\\s+(morning|afternoon|evening|night)'), (m) {
      final ok = setDate(inDays(m.group(1)!.toLowerCase() == 'today' ? 0 : 1));
      if (ok) setTime(parts[m.group(2)!.toLowerCase()]!, 0);
      return ok;
    });

    // Named days.
    take(_re('day after tomorrow|מחרתיים'), (_) => setDate(inDays(2)));
    take(_re('tomorrow|tmrw|tmr|מחר'), (_) => setDate(inDays(1)));
    take(_re('tonight|הערב|הלילה'), (_) {
      final ok = setDate(today);
      if (ok) setTime(20, 0);
      return ok;
    });
    take(_re('today|היום'), (_) => setDate(today));
    take(_re('next week|(?:ב)?שבוע הבא'), (_) => setDate(inDays(7)));
    take(_re('next month|(?:ב)?חודש הבא'), (_) => setDate(addMonths(today, 1)));
    take(_re('(?:(next)\\s+|(on|this)\\s+)?(${_alt(_weekdaysEn.keys)})'), (m) {
      final word = m.group(3)!.toLowerCase();
      // "sun", "sat", "mon" and "wed" are also ordinary words ("sun cream",
      // "sat down"): they count as days only after next / on / this.
      const ambiguous = {'sun', 'sat', 'mon', 'wed'};
      if (ambiguous.contains(word) && m.group(1) == null && m.group(2) == null) return false;
      final days = daysUntil(_weekdaysEn[word]!);
      // "next friday" said on a Monday means the Friday of next week.
      final thisWeek = days <= 7 - today.weekday;
      return setDate(inDays(m.group(1) != null && thisWeek ? days + 7 : days));
    });
    take(_re('(?:ב)?יום\\s+(${_alt(_weekdaysHe.keys)})|(?:ב)?(שבת)'), (m) {
      return setDate(nextWeekday(_weekdaysHe[m.group(1) ?? m.group(2)!]!));
    });

    // Written dates: "may 12", "12 may 2027", "12th of may".
    DateTime resolve(int day, int month, int? year) {
      if (year != null) return DateTime(year < 100 ? 2000 + year : year, month, day);
      final thisYear = DateTime(today.year, month, day);
      return thisYear.isBefore(today) ? DateTime(today.year + 1, month, day) : thisYear;
    }

    bool valid(int day, int month) => month >= 1 && month <= 12 && day >= 1 && day <= 31;
    final monthAlt = _alt(_months.keys);
    take(_re('(?:on\\s+)?(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($monthAlt)\\.?(?:,?\\s+(\\d{4}))?'), (m) {
      final day = int.parse(m.group(1)!);
      final month = _months[m.group(2)!.toLowerCase()]!;
      return valid(day, month) && setDate(resolve(day, month, int.tryParse(m.group(3) ?? '')));
    });
    take(_re('(?:on\\s+)?($monthAlt)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?'), (m) {
      final day = int.parse(m.group(2)!);
      final month = _months[m.group(1)!.toLowerCase()]!;
      return valid(day, month) && setDate(resolve(day, month, int.tryParse(m.group(3) ?? '')));
    });
    // Numeric dates: 12/5, 12.5., 12/5/27, 2027-05-12.
    take(_re('(\\d{4})-(\\d{1,2})-(\\d{1,2})'), (m) {
      final month = int.parse(m.group(2)!), day = int.parse(m.group(3)!);
      return valid(day, month) && setDate(DateTime(int.parse(m.group(1)!), month, day));
    });
    bool numeric(RegExpMatch m) {
      var day = int.parse(m.group(1)!), month = int.parse(m.group(2)!);
      if (month > 12 && day <= 12) (day, month) = (month, day);
      return valid(day, month) && setDate(resolve(day, month, int.tryParse(m.group(3) ?? '')));
    }

    take(_re('(?:on\\s+|ב-?)?(\\d{1,2})/(\\d{1,2})(?:/(\\d{4}|\\d{2}))?'), numeric);
    // With dots a year or a closing dot is needed, so "1.5 kg" stays text.
    take(
      RegExp('$_s(?:on\\s+|ב-?)?(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4}|\\d{2})?(?![\\p{L}\\p{N}])', unicode: true),
      numeric,
    );

    // Times.
    take(_re('(?:at\\s+)?(\\d{1,2})(?:[:.](\\d{2}))?\\s*(am|pm|a\\.m\\.?|p\\.m\\.?)'), (m) {
      var h = int.parse(m.group(1)!);
      if (h < 1 || h > 12) return false;
      final pm = m.group(3)!.toLowerCase().startsWith('p');
      h = h % 12 + (pm ? 12 : 0);
      return setTime(h, int.tryParse(m.group(2) ?? '') ?? 0);
    });
    take(_re('(?:at\\s+|בשעה\\s+|ב-?)?(\\d{1,2}):(\\d{2})'), (m) => setTime(int.parse(m.group(1)!), int.parse(m.group(2)!)));
    take(_re('(?:at|בשעה)\\s+(\\d{1,2})|ב-(\\d{1,2})'), (m) {
      var h = int.parse(m.group(1) ?? m.group(2)!);
      // "at 6" with no am/pm: 1 to 7 is far more often the afternoon.
      if (h >= 1 && h <= 7) h += 12;
      return setTime(h, 0);
    });
    take(_re('(?:at\\s+)?noon|בצהריים|בצהרים'), (_) => setTime(12, 0));
    take(_re('(?:at\\s+)?midnight|בחצות'), (_) => setTime(0, 0));
    take(_re('(?:in the|this)\\s+afternoon|אחר הצהריים|אחרי הצהריים|אחה"צ'), (_) => setTime(15, 0));
    take(_re('(?:in the|this)\\s+morning|בבוקר'), (_) => setTime(9, 0));
    take(_re('(?:in the|this)\\s+evening|בערב'), (_) => setTime(19, 0));

    // Put it together.
    DateTime? due;
    var hasTime = false;
    if (offset != null) {
      final at = clock.add(offset!);
      due = DateTime(at.year, at.month, at.day, at.hour, at.minute);
      hasTime = true;
    } else if (hour != null) {
      final day = date ?? today;
      due = DateTime(day.year, day.month, day.day, hour!, minute!);
      // "at 6pm" said at 8pm means tomorrow.
      if (date == null && !due.isAfter(clock)) due = due.add(const Duration(days: 1));
      hasTime = true;
    } else if (date != null) {
      due = date;
    } else if (recurrence != null) {
      due = today;
    }

    // Tidy what is left: spaces, and a dangling "at", "on", "by" or ב.
    var title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'\s+(at|on|by|in|ב|עד)$', caseSensitive: false, unicode: true), '');
    title = title.replaceAll(RegExp(r'^[\s,;:-]+|[\s,;:-]+$'), '');
    if (title.isEmpty && (due != null || tags.isNotEmpty)) {
      // Only a date was typed ("tomorrow"): keep it as the title.
      return QuickAdd(title: input.trim());
    }
    return QuickAdd(
      title: title,
      due: due,
      hasTime: hasTime,
      recurrence: recurrence,
      priority: priority,
      tags: tags,
    );
  }

  static bool _applyOffset(
    String unit,
    int n,
    DateTime today,
    DateTime Function(DateTime, int) addMonths,
    bool Function(DateTime) setDate,
    void Function(Duration) setOffset,
  ) {
    switch (unit) {
      case 'min':
        setOffset(Duration(minutes: n));
      case 'h':
        setOffset(Duration(hours: n));
      case 'd':
        return setDate(DateTime(today.year, today.month, today.day + n));
      case 'w':
        return setDate(DateTime(today.year, today.month, today.day + 7 * n));
      case 'm':
        return setDate(addMonths(today, n));
    }
    return true;
  }
}
