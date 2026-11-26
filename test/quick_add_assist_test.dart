import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages, ZtTheme;
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/core/services/quick_add_assist.dart';
import 'package:zero_trust_tasks/core/services/quick_add_parser.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_list_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/l10n/generated/app_l10n_en.dart';
import 'package:zero_trust_tasks/l10n/generated/app_l10n_he.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zt_assist/testing.dart';
import 'package:zt_assist/zt_assist.dart';

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String taskId) async {}
}

final l = AppL10nEn();

void main() {
  group('putting the two readings together', () {
    // A Thursday afternoon.
    final now = DateTime(2026, 11, 26, 14, 30);

    QuickAdd merged(String text, ZtAssistQuickAdd read) =>
        mergeAssistReading(QuickAddParser.parse(text, now: now), read, now: now);

    test('the title is ZT Assist\'s, the day and time the app read stay', () {
      // The phone test: the model got the title and dropped the time.
      final q = merged(
        'מחר ב-9 רופא שיניים, להזכיר שעה לפני',
        ZtAssistQuickAdd(title: 'רופא שיניים', day: DateTime(2026, 11, 27), remindMinutesBefore: 60),
      );
      expect(q.title, 'רופא שיניים');
      expect(q.due, DateTime(2026, 11, 27, 9));
      expect(q.hasTime, isTrue);
      expect(q.reminderAt, DateTime(2026, 11, 27, 8));
    });

    test('the app\'s own day wins over ZT Assist\'s', () {
      final q = merged(
        'Call the bank on friday',
        ZtAssistQuickAdd(title: 'Call the bank', day: DateTime(2026, 11, 28)),
      );
      // Friday is the 27th, whatever the model counted.
      expect(q.due, DateTime(2026, 11, 27));
      expect(q.hasTime, isFalse);
    });

    test('ZT Assist\'s time wins: it understands the wording', () {
      // The app reads "at 9" as 09:00 and does not see "in the evening".
      final q = merged(
        'Call mum tomorrow at 9 in the evening',
        ZtAssistQuickAdd(title: 'Call mum', day: DateTime(2026, 11, 27), hour: 21, minute: 0),
      );
      expect(q.due, DateTime(2026, 11, 27, 21));
      expect(q.hasTime, isTrue);
    });

    test('a day and a time the app could not read come from ZT Assist', () {
      final q = merged(
        'פגישה עם רואה החשבון בחמישה בדצמבר בארבע וחצי',
        ZtAssistQuickAdd(title: 'פגישה עם רואה החשבון', day: DateTime(2026, 12, 5), hour: 16, minute: 30),
      );
      expect(q.title, 'פגישה עם רואה החשבון');
      expect(q.due, DateTime(2026, 12, 5, 16, 30));
      expect(q.hasDate, isTrue);
    });

    test('only a time: today, or tomorrow when it has passed', () {
      final later = merged('Water the plants', const ZtAssistQuickAdd(title: 'Water the plants', hour: 18, minute: 0));
      expect(later.due, DateTime(2026, 11, 26, 18));
      final passed = merged('Water the plants', const ZtAssistQuickAdd(title: 'Water the plants', hour: 8, minute: 0));
      expect(passed.due, DateTime(2026, 11, 27, 8));
    });

    test('nothing about the day from ZT Assist leaves the app\'s reading alone', () {
      final own = QuickAddParser.parse('Send the report in 2 hours', now: now);
      final q = mergeAssistReading(own, const ZtAssistQuickAdd(title: 'Send the report'), now: now);
      expect(q.due, own.due);
      expect(q.hasTime, isTrue);
      expect(q.title, 'Send the report');
    });

    test('a reminder needs a time to count back from', () {
      final q = merged(
        'Buy a gift by friday',
        const ZtAssistQuickAdd(title: 'Buy a gift', remindMinutesBefore: 60),
      );
      expect(q.due, DateTime(2026, 11, 27));
      expect(q.reminderAt, isNull);
    });

    test('the length is ZT Assist\'s, else the app\'s', () {
      expect(merged('Write report 2h', const ZtAssistQuickAdd(title: 'Write report', lengthMinutes: 90)).minutes, 90);
      expect(merged('Write report 2h', const ZtAssistQuickAdd(title: 'Write report')).minutes, 120);
    });

    test('repeats, priority and tags stay the app\'s, out of the title', () {
      final q = merged(
        'Pay rent every month !high #home',
        const ZtAssistQuickAdd(title: 'Pay rent !high #home'),
      );
      expect(q.title, 'Pay rent');
      expect(q.recurrence?.frequency, RecurrenceFrequency.monthly);
      expect(q.priority, TaskPriority.high);
      expect(q.tags, ['home']);
    });

    test('no title from ZT Assist keeps the app\'s', () {
      final q = merged('Call mum tomorrow', ZtAssistQuickAdd(day: DateTime(2026, 11, 27)));
      expect(q.title, 'Call mum');
    });

    test('the app\'s reading says whether a day was named', () {
      expect(QuickAddParser.parse('Call mum tomorrow', now: now).hasDate, isTrue);
      expect(QuickAddParser.parse('Call mum at 6pm', now: now).hasDate, isFalse);
      expect(QuickAddParser.parse('Call mum in 2 hours', now: now).hasDate, isFalse);
      expect(QuickAddParser.parse('Call mum', now: now).hasDate, isFalse);
    });
  });

  group('the quick add sheet', () {
    late TaskManager manager;
    late MemoryWriter writer;
    late TaskListProvider lists;
    late ZtAssist before;

    setUp(() {
      writer = MemoryWriter();
      manager = TaskManager(reminders: false)..attach(writer: writer);
      lists = TaskListProvider()..attach(save: (_) async {}, delete: (_) async {});
      before = ZtAssist.instance;
    });

    tearDown(() => ZtAssist.instance = before);

    Future<void> pumpSheet(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      double width = 412,
    }) async {
      // A phone's width. The test font is wider than a real one, and the
      // sheet's last row (star, list, More options, Add) needs this much
      // with it.
      tester.view.physicalSize = Size(width * 2, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          taskManagerProvider.overrideWith((ref) => manager),
          taskListProvider.overrideWith((ref) => lists),
          remindersEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          // The suite's real theme, as inside the app.
          theme: ZtTheme.light(accent: Colors.teal),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('he')],
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          home: const Scaffold(body: QuickAddSheet()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    final button = find.byKey(const ValueKey('quick-add-assist'));
    final read = find.byKey(const ValueKey('quick-add-assist-read'));

    testWidgets('without ZT Assist on the phone there is no button', (tester) async {
      ZtAssist.instance = FakeZtAssist(state: ZtAssistAvailability.notInstalled);
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      expect(button, findsNothing);
    });

    testWidgets('the button shows once something is typed, under the field', (tester) async {
      ZtAssist.instance = FakeZtAssist();
      await pumpSheet(tester);
      expect(button, findsNothing);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      expect(find.text(l.quickAddAssist), findsOneWidget);
      final field = tester.getRect(find.byType(TextField));
      final add = tester.getRect(find.widgetWithText(FilledButton, l.add));
      final assist = tester.getRect(button);
      expect(assist.top, greaterThan(field.bottom));
      expect(assist.bottom, lessThanOrEqualTo(add.top));
      // Inside the sheet, at its start, and not stretched across it.
      expect(assist.left, greaterThanOrEqualTo(field.left));
      expect(assist.right, lessThanOrEqualTo(field.right));
      expect(assist.width, lessThan(field.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ZT Assist reads the line, and what it read is added', (tester) async {
      final assist = FakeZtAssist(
        answer: (_) => [
          '{"title":"Dentist","date":null,',
          '"time":"21:00","minutes":null,"remind":60,"place":null}',
        ],
      );
      ZtAssist.instance = assist;
      await pumpSheet(tester);
      const text = 'Remind me that I have the dentist tomorrow at 9 in the evening, tell me an hour before';
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(assist.requests.single.task, ZtAssistTask.quickAdd);
      expect(assist.requests.single.text, text);
      // The title, the time and the reminder are ZT Assist's; the day is
      // the app's own "tomorrow".
      expect(find.text(l.titleIs('Dentist')), findsOneWidget);
      expect(find.text('${l.tomorrow} 21:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-add-reminder')), findsOneWidget);
      expect(find.text(l.reminderAtIs('${l.tomorrow} 20:00')), findsOneWidget);
      expect(find.text(l.quickAddAssistRead), findsOneWidget);
      expect(button, findsNothing);
      // The note that it is ZT Assist's reading sits under the title line.
      expect(
        tester.getTopLeft(read).dy,
        greaterThan(tester.getTopLeft(find.text(l.titleIs('Dentist'))).dy),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, l.add));
      await tester.pumpAndSettle();
      final task = writer.saved.values.single;
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(task.title, 'Dentist');
      expect(task.dueDate, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21));
      expect(task.reminderAt, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20));
    });

    testWidgets('typing again drops what ZT Assist read', (tester) async {
      ZtAssist.instance = FakeZtAssist(answer: (_) => ['{"title":"Dentist","time":"21:00"}']);
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'The dentist tomorrow at 9 in the evening');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(read, findsOneWidget);

      await tester.enterText(find.byType(TextField), 'The dentist tomorrow at 9 in the evening!');
      await tester.pump();
      expect(read, findsNothing);
      expect(find.text('${l.tomorrow} 09:00'), findsOneWidget);
      expect(button, findsOneWidget);
    });

    testWidgets('while it reads there is a Stop, and Stop stops the model', (tester) async {
      final gate = Completer<void>();
      final assist = FakeZtAssist(answer: (_) => ['{"title":"Dentist"}'], beforePiece: () => gate.future);
      ZtAssist.instance = assist;
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(find.text(l.quickAddAssistReading), findsOneWidget);
      final stop = find.byKey(const ValueKey('quick-add-assist-stop'));
      // Stop is on screen, at the end of the line that says it is reading.
      final line = tester.getRect(find.byKey(const ValueKey('quick-add-assist-reading')));
      expect(tester.getRect(stop).right, lessThanOrEqualTo(line.right));
      expect(tester.getRect(stop).right, lessThanOrEqualTo(412));
      expect(button, findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(stop);
      await tester.pump();
      expect(assist.cancelled, 1);
      expect(button, findsOneWidget);
      expect(read, findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(read, findsNothing);
    });

    testWidgets('typing while it reads stops the model', (tester) async {
      final gate = Completer<void>();
      final assist = FakeZtAssist(answer: (_) => ['{"title":"Dentist"}'], beforePiece: () => gate.future);
      ZtAssist.instance = assist;
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 10');
      await tester.pump();
      expect(assist.cancelled, 1);
      expect(button, findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(read, findsNothing);
    });

    testWidgets('an answer that cannot be used is said, and the usual reading stays', (tester) async {
      ZtAssist.instance = FakeZtAssist(answer: (_) => ['I am not sure what you mean.']);
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(l.quickAddAssistNotUnderstood), findsOneWidget);
      expect(find.text('${l.tomorrow} 09:00'), findsOneWidget);
      expect(read, findsNothing);
      // It can be asked again.
      expect(button, findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('quick-add-assist-problem'))).dy,
        greaterThan(tester.getTopLeft(button).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('each failure is said in words', (tester) async {
      final assist = FakeZtAssist(answer: (_) => const []);
      ZtAssist.instance = assist;
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      for (final (error, words) in [
        (ZtAssistError.noModel, l.assistNoModel),
        (ZtAssistError.needsUpdate, l.assistNeedsUpdate),
        (ZtAssistError.loadFailed, l.assistLoadFailed),
        (ZtAssistError.stopped, l.assistStopped),
        (ZtAssistError.failed, l.assistFailed),
        (ZtAssistError.notInstalled, l.assistNotInstalled),
      ]) {
        assist.error = error;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text(words), findsOneWidget, reason: '$error');
        expect(tester.takeException(), isNull, reason: '$error');
      }
    });

    testWidgets('"Keep as typed" hides ZT Assist too', (tester) async {
      ZtAssist.instance = FakeZtAssist();
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      await tester.tap(find.text(l.keepAsTyped));
      await tester.pump();
      expect(button, findsNothing);
    });

    testWidgets('leaving while it reads stops the model', (tester) async {
      final gate = Completer<void>();
      final assist = FakeZtAssist(answer: (_) => ['{"title":"Dentist"}'], beforePiece: () => gate.future);
      ZtAssist.instance = assist;
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'Dentist tomorrow at 9');
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(assist.cancelled, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('in Hebrew the button and the note fit', (tester) async {
      final he = AppL10nHe();
      ZtAssist.instance = FakeZtAssist(
        answer: (_) => ['{"title":"רופא שיניים","date":null,"time":null,"remind":60}'],
      );
      // The last row's Hebrew words are wider still in the test font.
      await pumpSheet(tester, locale: const Locale('he'), width: 460);
      await tester.enterText(find.byType(TextField), 'מחר ב-9 רופא שיניים, להזכיר שעה לפני');
      await tester.pump();
      expect(find.text(he.quickAddAssist), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(he.titleIs('רופא שיניים')), findsOneWidget);
      expect(find.text(he.quickAddAssistRead), findsOneWidget);
      expect(find.text(he.reminderAtIs('${he.tomorrow} 08:00')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
