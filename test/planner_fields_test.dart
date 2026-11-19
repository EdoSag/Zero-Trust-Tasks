import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages;
import 'package:zero_trust_tasks/components/planner_fields.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/components/task_list_dialogs.dart';
import 'package:zero_trust_tasks/core/services/quick_add_parser.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_list_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/l10n/generated/app_l10n_en.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/models/task_plan.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/pages/task_details_screen.dart';
import 'package:zero_trust_tasks/suite/planned_times.dart';
import 'package:zero_trust_tasks/task_priority.dart';

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String taskId) async {}
}

Map<String, dynamic> oldTask(String id, String title) => {
      'id': id,
      'title': title,
      'priority': 'medium',
      'isCompleted': false,
      'createdAt': '2026-01-01T10:00:00.000',
      'updatedAt': '2026-01-02T10:00:00.000',
    };

Map<String, Object?> blockItem(
  String taskId,
  DateTime start,
  int minutes, {
  bool done = false,
  String? occurrence,
  String calendarId = 'planner',
}) =>
    {
      'kind': 'event',
      'title': 'Write report',
      'calendarId': calendarId,
      'start': start.toUtc().toIso8601String(),
      'end': start.add(Duration(minutes: minutes)).toUtc().toIso8601String(),
      'allDay': false,
      'plan': {
        'type': 'task',
        'taskId': taskId,
        'done': done,
        'locked': false,
        'occurrence': ?occurrence,
      },
    };

final l = AppL10nEn();

/// Checks that the widgets found by [finders] are on screen, each below the
/// one before it.
void expectInOrder(WidgetTester tester, List<Finder> finders) {
  double? last;
  for (final f in finders) {
    expect(f, findsOneWidget);
    final y = tester.getTopLeft(f).dy;
    if (last != null) expect(y, greaterThan(last), reason: '$f should be below the one before it');
    last = y;
  }
}

void main() {
  group('the Planner fields on a task', () {
    test('an old task has none, and writes none', () {
      final task = Task.fromJson(oldTask('t1', 'Old'));
      expect(task.hasPlanFields, isFalse);
      expect(task.planMinutes, isNull);
      expect(task.planAuto, isNull);
      final json = task.toJson();
      expect(json.keys.where(TaskPlan.keys.contains), isEmpty);
      expect(Task.fromJson(json).toJson(), json);
    });

    test('fields ZT Calendar wrote come back exactly, through any edit', () {
      final json = {
        ...oldTask('t1', 'Write report'),
        'planMinutes': 180,
        'planAuto': true,
        'planMinChunk': 30,
        'planMaxChunk': 90,
        'planHours': 'personal',
      };
      final task = Task.fromJson(json);
      expect(task.planMinutes, 180);
      expect(task.planAuto, isTrue);
      expect(task.planMinChunk, 30);
      expect(task.planMaxChunk, 90);
      expect(task.planPersonal, isTrue);
      final edited = task.copyWith(title: 'Write the report', isCompleted: true).toJson();
      for (final k in TaskPlan.keys) {
        expect(edited[k], json[k], reason: k);
      }
    });

    test('withPlan sets and removes only the Planner fields', () {
      final task = Task.fromJson({...oldTask('t1', 'A'), 'planMinutes': 60, 'fromTheFuture': 1});
      final changed = task.withPlan({TaskPlan.minutesKey: null, TaskPlan.autoKey: false});
      expect(changed.planMinutes, isNull);
      expect(changed.planAuto, isFalse);
      expect(changed.toJson().containsKey('planMinutes'), isFalse);
      expect(changed.toJson()['fromTheFuture'], 1);
      expect(changed.title, 'A');
    });

    test('odd values are read safely', () {
      final task = Task.fromJson({...oldTask('t1', 'A'), 'planMinutes': 'two', 'planAuto': 'yes', 'planMaxChunk': 99999});
      expect(task.planMinutes, isNull);
      expect(task.planAuto, isNull);
      expect(task.planMaxChunk, TaskPlan.maxMinutes);
    });

    test('a list that plans its new tasks switches them on, unless set', () {
      final list = TaskList.create(name: 'Work').withAutoPlan(true);
      expect(list.autoPlan, isTrue);
      expect(TaskList.fromJson(list.toJson()).autoPlan, isTrue);
      expect(list.withAutoPlan(false).toJson().containsKey('planAuto'), isFalse);
      expect(Task.create(title: 'A').forNewIn(list).planAuto, isTrue);
      expect(Task.create(title: 'A').withPlan({TaskPlan.autoKey: false}).forNewIn(list).planAuto, isFalse);
      expect(Task.create(title: 'A').forNewIn(TaskList.fallbackDefault).planAuto, isNull);
      // A shared list is never planned (the Planner doesn't read them yet).
      final shared = list.withShared(const SharedListInfo(spaceId: 's1'));
      expect(shared.autoPlan, isFalse);
    });
  });

  group('quick add reads how long a task takes', () {
    final now = DateTime(2026, 11, 16, 9); // a Monday

    test('the example from the plan', () {
      final q = QuickAddParser.parse('Write report 2h by Friday !high', now: now);
      expect(q.title, 'Write report');
      expect(q.minutes, 120);
      expect(q.due, DateTime(2026, 11, 20));
      expect(q.priority, TaskPriority.high);
    });

    test('English lengths', () {
      int? m(String s) => QuickAddParser.parse(s, now: now).minutes;
      expect(m('Read contract 1.5h'), 90);
      expect(m('Read contract 1,5h'), 90);
      expect(m('Read contract 1h30'), 90);
      expect(m('Read contract 1h 30m'), 90);
      expect(m('Read contract 1 hour and 15 minutes'), 75);
      expect(m('Call the bank 15 min'), 15);
      expect(m('Call the bank 45m'), 45);
      expect(m('Gym for 2 hours'), 120);
      expect(QuickAddParser.parse('Gym for 2 hours', now: now).title, 'Gym');
    });

    test('Hebrew lengths', () {
      int? m(String s) => QuickAddParser.parse(s, now: now).minutes;
      expect(m('לכתוב דוח שעתיים'), 120);
      expect(m('לכתוב דוח שעה וחצי'), 90);
      expect(m('להתקשר לבנק חצי שעה'), 30);
      expect(m('להתקשר לבנק רבע שעה'), 15);
      expect(m('לכתוב דוח 3 שעות'), 180);
      expect(m('להתקשר 20 דקות'), 20);
      expect(QuickAddParser.parse('לכתוב דוח שעתיים מחר', now: now).title, 'לכתוב דוח');
    });

    test('a due time is not a length', () {
      final inTwo = QuickAddParser.parse('Call mum in 2 hours', now: now);
      expect(inTwo.minutes, isNull);
      expect(inTwo.due, DateTime(2026, 11, 16, 11));
      final he = QuickAddParser.parse('להתקשר לאמא בעוד שעתיים', now: now);
      expect(he.minutes, isNull);
      expect(he.due, DateTime(2026, 11, 16, 11));
      expect(QuickAddParser.parse('Call mum 6pm', now: now).minutes, isNull);
      expect(QuickAddParser.parse('Call mum 18:30', now: now).minutes, isNull);
    });

    test('other numbers stay in the title', () {
      expect(QuickAddParser.parse('Buy 1.5 kg flour', now: now).minutes, isNull);
      expect(QuickAddParser.parse('Buy 1.5 kg flour', now: now).title, 'Buy 1.5 kg flour');
      expect(QuickAddParser.parse('Read 3 books', now: now).minutes, isNull);
      expect(QuickAddParser.parse('Run 2m', now: now).minutes, isNull); // too short to plan
      expect(QuickAddParser.parse('Call 2', now: now).title, 'Call 2');
    });

    test('a length alone keeps the text as the title', () {
      final q = QuickAddParser.parse('2h', now: now);
      expect(q.title, '2h');
    });
  });

  group('planned times from ZT Calendar', () {
    final now = DateTime(2026, 11, 16, 9);

    test('only the Planner\'s task blocks are read', () {
      expect(PlannedBlock.fromItem(blockItem('t1', now, 60))!.taskId, 't1');
      expect(PlannedBlock.fromItem(blockItem('t1', now, 60, calendarId: 'personal')), isNull);
      expect(PlannedBlock.fromItem({...blockItem('t1', now, 60), 'plan': {'type': 'habit', 'habitId': 'h1'}}), isNull);
      expect(PlannedBlock.fromItem({...blockItem('t1', now, 60), 'kind': 'calendar'}), isNull);
      expect(PlannedBlock.fromItem({...blockItem('t1', now, 60), 'end': 'soon'}), isNull);
      final b = PlannedBlock.fromItem(blockItem('t1', now, 90, done: true))!;
      expect(b.start, now);
      expect(b.minutes, 90);
      expect(b.done, isTrue);
    });

    test('next block, what is done, and what is still to come', () {
      final task = Task.fromJson({...oldTask('t1', 'Write report'), 'planMinutes': 180});
      final blocks = [
        PlannedBlock.fromItem(blockItem('t1', now.subtract(const Duration(days: 1)), 60, done: true))!,
        PlannedBlock.fromItem(blockItem('t1', now.add(const Duration(days: 2)), 60))!,
        PlannedBlock.fromItem(blockItem('t1', now.add(const Duration(days: 1)), 60))!,
        // Passed and not answered: neither next nor done.
        PlannedBlock.fromItem(blockItem('t1', now.subtract(const Duration(hours: 3)), 60))!,
      ];
      final info = TaskPlanInfo.of(task, blocks, now: now);
      expect(info.next!.start, now.add(const Duration(days: 1)));
      expect(info.upcoming, 2);
      expect(info.doneMinutes, 60);
      expect(plannedSummary(l, info, now: now), 'Planned: Tomorrow 09:00 · 1 h of 3 h done');
    });

    test('a repeating task counts only the blocks of its current date', () {
      final due = DateTime(2026, 11, 17);
      final task = Task.fromJson({
        ...oldTask('t1', 'Weekly report'),
        'dueDate': due.toIso8601String(),
        'recurrence': const RecurrenceRule(frequency: RecurrenceFrequency.weekly).toJson(),
      });
      final blocks = [
        PlannedBlock.fromItem(blockItem('t1', now.subtract(const Duration(days: 7)), 60,
            done: true, occurrence: DateTime(2026, 11, 10).toIso8601String()))!,
        PlannedBlock.fromItem(blockItem('t1', now.subtract(const Duration(hours: 2)), 30,
            done: true, occurrence: due.toIso8601String()))!,
      ];
      expect(TaskPlanInfo.of(task, blocks, now: now).doneMinutes, 30);
    });

    test('lengths read naturally', () {
      expect(formatPlanLength(l, 45), '45 min');
      expect(formatPlanLength(l, 120), '2 h');
      expect(formatPlanLength(l, 90), '1 h 30 min');
    });
  });

  group('screens', () {
    late TaskManager manager;
    late MemoryWriter writer;
    late TaskListProvider lists;
    late StreamController<Map<String, List<PlannedBlock>>> planned;

    setUp(() {
      writer = MemoryWriter();
      manager = TaskManager(reminders: false)..attach(writer: writer);
      lists = TaskListProvider()..attach(save: (_) async {}, delete: (_) async {});
      planned = StreamController();
    });

    Widget host(Widget child, {Locale locale = const Locale('en')}) => ProviderScope(
          overrides: [
            taskManagerProvider.overrideWith((ref) => manager),
            taskListProvider.overrideWith((ref) => lists),
            remindersEnabledProvider.overrideWithValue(false),
            plannedBlocksProvider.overrideWith((ref) => planned.stream),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('he')],
            localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
            home: child,
          ),
        );

    testWidgets('the editor has Length and Auto-schedule after the reminders, before Repeat', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const AddTaskScreen()));
      await tester.pumpAndSettle();
      expectInOrder(tester, [
        find.byKey(const ValueKey('location-reminder')),
        find.byKey(const ValueKey('plan-length')),
        find.byKey(const ValueKey('plan-auto')),
        find.byKey(const ValueKey('plan-options')),
        find.text(l.repeat),
      ]);
      expect(find.text(l.noLength), findsOneWidget);
      expect(find.text(l.autoScheduleUnset), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, l.title), 'Write report');
      await tester.tap(find.byKey(const ValueKey('plan-length')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-choice-90')));
      await tester.pumpAndSettle();
      expect(find.text(l.lengthIs('1 h 30 min')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-auto')));
      await tester.pumpAndSettle();
      expect(find.text(l.autoScheduleOn), findsOneWidget);

      // Planner options: shortest block and hours.
      await tester.tap(find.byKey(const ValueKey('plan-options')));
      await tester.pumpAndSettle();
      expectInOrder(tester, [
        find.byKey(const ValueKey('plan-min-chunk')),
        find.byKey(const ValueKey('plan-max-chunk')),
        find.byKey(const ValueKey('plan-hours')),
      ]);
      await tester.tap(find.byKey(const ValueKey('plan-min-chunk')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-choice-45')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-hours')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.personalHours).last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      final saved = writer.saved.values.single;
      expect(saved.title, 'Write report');
      expect(saved.planMinutes, 90);
      expect(saved.planAuto, isTrue);
      expect(saved.planMinChunk, 45);
      expect(saved.planPersonal, isTrue);
      expect(saved.toJson().containsKey('planMaxChunk'), isFalse);
    });

    testWidgets('editing an old task without touching the Planner adds nothing to it', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final old = Task.fromJson(oldTask('t1', 'Old'));
      manager.setShared(const []);
      await manager.importTasks([old]);
      await tester.pumpWidget(host(AddTaskScreen(taskToEdit: manager.tasks.single)));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, l.title), 'Old, renamed');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      final json = writer.saved['t1']!.toJson();
      expect(json['title'], 'Old, renamed');
      expect(json.keys.where(TaskPlan.keys.contains), isEmpty);
    });

    testWidgets('a new task in a list that plans its tasks starts switched on', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final work = TaskList.create(name: 'Work').withAutoPlan(true);
      await lists.save(work);
      await tester.pumpWidget(host(AddTaskScreen(initialListId: work.id)));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('plan-auto'))).value, isTrue);
      expect(find.text(l.autoScheduleOn), findsOneWidget);
    });

    testWidgets('quick add shows the length and saves it', (tester) async {
      await tester.pumpWidget(host(const Scaffold(body: QuickAddSheet())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Write report 2h !high');
      await tester.pump();
      expect(find.byKey(const ValueKey('quick-add-length')), findsOneWidget);
      expect(find.text(l.lengthIs('2 h')), findsOneWidget);
      expect(find.text(l.titleIs('Write report')), findsOneWidget);
      // The length chip sits with the others, above the title line.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('quick-add-length'))).dy,
        lessThan(tester.getTopLeft(find.text(l.titleIs('Write report'))).dy),
      );
    });

    testWidgets('a planned task shows when it is planned, under its title', (tester) async {
      final task = Task.fromJson({...oldTask('t1', 'Write report'), 'planMinutes': 120, 'planAuto': true});
      final now = DateTime.now();
      final soon = DateTime(now.year, now.month, now.day + 1, 10);
      await tester.pumpWidget(host(Scaffold(body: ListView(children: [TaskCard(task: task)]))));
      planned.add({
        't1': [
          PlannedBlock.fromItem(blockItem('t1', soon, 60))!,
          PlannedBlock.fromItem(blockItem('t1', now.subtract(const Duration(days: 1)), 60, done: true))!,
        ],
      });
      await tester.pumpAndSettle();
      final chip = find.byKey(const ValueKey('planned-chip-t1'));
      expect(chip, findsOneWidget);
      expect(find.text('Planned: Tomorrow 10:00 · 1 h of 2 h done'), findsOneWidget);
      expect(tester.getTopLeft(chip).dy, greaterThan(tester.getTopLeft(find.text('Write report')).dy));
      // A task the Planner has nothing for shows no chip.
      planned.add(const {});
      await tester.pumpAndSettle();
      expect(chip, findsNothing);
    });

    testWidgets('the task page lists length, Auto-schedule and the next time', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final task = Task.fromJson({...oldTask('t1', 'Write report'), 'planMinutes': 120, 'planAuto': true});
      await manager.importTasks([task]);
      final now = DateTime.now();
      final soon = DateTime(now.year, now.month, now.day + 1, 10);
      await tester.pumpWidget(host(TaskDetailsScreen(task: manager.tasks.single)));
      planned.add({
        't1': [
          PlannedBlock.fromItem(blockItem('t1', soon, 60))!,
          PlannedBlock.fromItem(blockItem('t1', soon.add(const Duration(days: 1)), 60))!,
        ],
      });
      await tester.pumpAndSettle();
      expectInOrder(tester, [
        find.byKey(const ValueKey('details-length')),
        find.byKey(const ValueKey('details-auto')),
        find.byKey(const ValueKey('details-planned')),
        find.text(l.openZtCalendar),
      ]);
      expect(find.text('Tomorrow 10:00–11:00 · 1 more'), findsOneWidget);
    });

    testWidgets('a list can plan every new task, from its options', (tester) async {
      final saved = <TaskList>[];
      lists.attach(save: (l) async => saved.add(l), delete: (_) async {});
      final work = TaskList.create(name: 'Work');
      await lists.save(work);
      saved.clear();
      await tester.pumpWidget(host(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => TaskListDialogs.showOptions(context, work),
            child: const Text('options'),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('options'));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('list-auto-plan'));
      // Right under "Rename or change colour".
      expectInOrder(tester, [find.text(l.renameOrChangeColour), toggle]);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(saved.single.autoPlan, isTrue);
      expect(saved.single.name, 'Work');
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      // Renaming from the same sheet keeps the switch as it now is.
      await tester.tap(find.text(l.renameOrChangeColour));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Office');
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(saved.last.name, 'Office');
      expect(saved.last.autoPlan, isTrue);
    });

    testWidgets('Hebrew: the editor section reads right to left', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const AddTaskScreen(), locale: const Locale('he')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('plan-length'));
      final icon = find.descendant(of: tile, matching: find.byIcon(Icons.timelapse));
      final text = find.descendant(of: tile, matching: find.text('בלי משך'));
      expect(text, findsOneWidget);
      // The icon starts the line: on the right in Hebrew.
      expect(tester.getCenter(icon).dx, greaterThan(tester.getCenter(text).dx));
    });
  });
}
