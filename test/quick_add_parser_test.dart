import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/core/services/quick_add_parser.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/task_priority.dart';

void main() {
  // A Tuesday, 10:30.
  final now = DateTime(2026, 11, 10, 10, 30);
  QuickAdd p(String s) => QuickAddParser.parse(s, now: now);

  void expectDue(String input, String title, DateTime due, {bool time = false}) {
    final r = p(input);
    expect(r.title, title, reason: input);
    expect(r.due, due, reason: input);
    expect(r.hasTime, time, reason: input);
  }

  test('plain text stays a title', () {
    for (final s in [
      'Buy milk',
      'buy 1.5 kg flour',
      'sun cream',
      'morning run',
      'read chapter 12',
      'call 054 1234567',
      'May I ask Dana',
      'לקנות חלב',
      'שיעור שני בפסנתר',
    ]) {
      final r = p(s);
      expect(r.title, s, reason: s);
      expect(r.due, isNull, reason: s);
    }
  });

  test('English days and times', () {
    expectDue('call mum tomorrow 6pm', 'call mum', DateTime(2026, 11, 11, 18), time: true);
    expectDue('Call mum tomorrow at 6', 'Call mum', DateTime(2026, 11, 11, 18), time: true);
    expectDue('pay rent today', 'pay rent', DateTime(2026, 11, 10));
    expectDue('movie tonight', 'movie', DateTime(2026, 11, 10, 20), time: true);
    expectDue('dentist friday 9:30am', 'dentist', DateTime(2026, 11, 13, 9, 30), time: true);
    expectDue('report next friday', 'report', DateTime(2026, 11, 20));
    expectDue('gym on tue', 'gym', DateTime(2026, 11, 17));
    expectDue('gym on sun', 'gym', DateTime(2026, 11, 15));
    expectDue('standup at 9:15', 'standup', DateTime(2026, 11, 11, 9, 15), time: true);
    expectDue('lunch at noon', 'lunch', DateTime(2026, 11, 10, 12), time: true);
    expectDue('walk tomorrow morning', 'walk', DateTime(2026, 11, 11, 9), time: true);
    expectDue('day after tomorrow: passport', 'passport', DateTime(2026, 11, 12));
    expectDue('plan trip next week', 'plan trip', DateTime(2026, 11, 17));
    expectDue('renew next month', 'renew', DateTime(2026, 12, 10));
  });

  test('relative amounts', () {
    expectDue('check oven in 20 minutes', 'check oven', DateTime(2026, 11, 10, 10, 50), time: true);
    expectDue('call back in an hour', 'call back', DateTime(2026, 11, 10, 11, 30), time: true);
    expectDue('water plants in 3 days', 'water plants', DateTime(2026, 11, 13));
    expectDue('review in 2 weeks', 'review', DateTime(2026, 11, 24));
  });

  test('written and numeric dates, day first', () {
    expectDue('party dec 24', 'party', DateTime(2026, 12, 24));
    expectDue('party 24 dec 2027', 'party', DateTime(2027, 12, 24));
    expectDue('taxes on the 3rd of march', 'taxes', DateTime(2027, 3, 3));
    expectDue('taxes 12/5', 'taxes', DateTime(2027, 5, 12));
    expectDue('taxes 12.5.2027', 'taxes', DateTime(2027, 5, 12));
    expectDue('taxes 12.5. 14:00', 'taxes', DateTime(2027, 5, 12, 14), time: true);
    expectDue('visa 2027-01-31', 'visa', DateTime(2027, 1, 31));
    expectDue('us style 5/25', 'us style', DateTime(2027, 5, 25));
  });

  test('repeats, priority and tags', () {
    var r = p('take pills every day 8am !high #health');
    expect(r.title, 'take pills');
    expect(r.recurrence!.frequency, RecurrenceFrequency.daily);
    expect(r.due, DateTime(2026, 11, 11, 8));
    expect(r.priority, TaskPriority.high);
    expect(r.tags, ['health']);

    r = p('bins every 2 weeks');
    expect(r.recurrence!.interval, 2);
    expect(r.recurrence!.frequency, RecurrenceFrequency.weekly);
    expect(r.due, DateTime(2026, 11, 10));

    r = p('team sync every monday 10:00');
    expect(r.title, 'team sync');
    expect(r.recurrence!.weekdays, [1]);
    expect(r.due, DateTime(2026, 11, 16, 10));
  });

  test('Hebrew', () {
    expectDue('להתקשר לאמא מחר ב-18:00', 'להתקשר לאמא', DateTime(2026, 11, 11, 18), time: true);
    expectDue('להתקשר לאמא מחר בשעה 6', 'להתקשר לאמא', DateTime(2026, 11, 11, 18), time: true);
    expectDue('לשלם חשבון היום', 'לשלם חשבון', DateTime(2026, 11, 10));
    expectDue('סרט הערב', 'סרט', DateTime(2026, 11, 10, 20), time: true);
    expectDue('רופא שיניים ביום חמישי בבוקר', 'רופא שיניים', DateTime(2026, 11, 12, 9), time: true);
    expectDue('ארוחה בשבת', 'ארוחה', DateTime(2026, 11, 14));
    expectDue('להשקות בעוד 3 ימים', 'להשקות', DateTime(2026, 11, 13));
    expectDue('לחזור בעוד שעתיים', 'לחזור', DateTime(2026, 11, 10, 12, 30), time: true);
    expectDue('דוח מחרתיים', 'דוח', DateTime(2026, 11, 12));
    expectDue('לתכנן טיול בשבוע הבא', 'לתכנן טיול', DateTime(2026, 11, 17));
    expectDue('מס הכנסה ב-12/5', 'מס הכנסה', DateTime(2027, 5, 12));
    final r = p('לקחת כדורים כל יום ב-8:00 !דחוף');
    expect(r.title, 'לקחת כדורים');
    expect(r.recurrence!.frequency, RecurrenceFrequency.daily);
    expect(r.due, DateTime(2026, 11, 11, 8));
    expect(r.priority, TaskPriority.critical);
  });

  test('a time that has passed today means tomorrow', () {
    expectDue('standup 9am', 'standup', DateTime(2026, 11, 11, 9), time: true);
    expectDue('standup 3pm', 'standup', DateTime(2026, 11, 10, 15), time: true);
  });

  test('only a date typed: it is the title', () {
    final r = p('tomorrow');
    expect(r.title, 'tomorrow');
    expect(r.due, isNull);
  });
}
