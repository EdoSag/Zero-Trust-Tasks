import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages;
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/pages/focus_timer_page.dart';
import 'package:zero_trust_tasks/pages/pick_for_keyboard_page.dart';
import 'package:zero_trust_tasks/suite/zt_time.dart';

class MemoryWriter implements TaskWriter {
  @override
  Future<void> save(Task task) async {}
  @override
  Future<void> delete(String taskId) async {}
}

Widget host(TaskManager manager, Widget child) => ProviderScope(
      overrides: [
        taskManagerProvider.overrideWith((ref) => manager),
        remindersEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        supportedLocales: const [Locale('en'), Locale('he')],
        localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
        home: child,
      ),
    );

void main() {
  test('focus minutes live in the task extra fields and survive JSON', () {
    final t = Task.create(title: 'Write').withFocusMinutes(40);
    expect(t.focusMinutes, 40);
    expect(Task.fromJson(t.toJson()).focusMinutes, 40);
    expect(Task.create(title: 'New').focusMinutes, 0);
  });

  testWidgets('a 15 minute focus adds the minutes to the task and offers ZT Time', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final manager = TaskManager(reminders: false)..attach(writer: MemoryWriter());
    final task = Task.create(title: 'Write the report').withFocusMinutes(10);
    await manager.addTask(task);
    var now = DateTime(2026, 11, 22, 9);
    await tester.pumpWidget(host(manager, FocusTimerPage(task: task, clock: () => now)));
    await tester.pumpAndSettle();

    expect(find.text('Focused on this task: 10 minutes'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();
    expect(find.text('15:00'), findsOneWidget);
    // The title above the clock, the start button below it.
    expect(tester.getTopLeft(find.text('Write the report')).dy, lessThan(tester.getTopLeft(find.text('15:00')).dy));
    expect(tester.getTopLeft(find.text('15:00')).dy, lessThan(tester.getTopLeft(find.text('Start focusing')).dy));

    await tester.tap(find.text('Start focusing'));
    await tester.pump();
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10:00'), findsOneWidget);

    // Paused time doesn't count.
    await tester.tap(find.text('Pause'));
    await tester.pump();
    now = now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('10:00'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    now = now.add(const Duration(minutes: 11));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('15 minutes of focus added to the task.'), findsOneWidget);
    expect(manager.tasks.single.focusMinutes, 25);
    expect(find.text('Log in ZT Time'), findsOneWidget);

    // ZT Time isn't installed: a note with a way to get it.
    final calls = <MethodCall>[];
    var answer = 'missing';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('zt_tasks/time'), (call) async {
      calls.add(call);
      return answer;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('zt_tasks/time'), null));
    await tester.tap(find.text('Log in ZT Time'));
    await tester.pumpAndSettle();
    expect(find.text("ZT Time isn't installed on this phone."), findsOneWidget);

    // Installed and saved: the stretch went with the task's id and title.
    answer = 'done';
    await tester.tap(find.text('Log in ZT Time'));
    await tester.pumpAndSettle();
    expect(find.text('Logged in ZT Time'), findsWidgets);
    final args = calls.last.arguments as Map;
    expect(calls.last.method, 'track');
    expect(args['id'], task.id);
    expect(args['title'], 'Write the report');
    expect(args['start'], DateTime(2026, 11, 22, 9).millisecondsSinceEpoch);
    expect(args['end'], now.millisecondsSinceEpoch);
  });

  testWidgets('ZT Time asking for a task gets it with one tap', (tester) async {
    final manager = TaskManager(reminders: false)..attach(writer: MemoryWriter());
    final task = Task.create(title: 'Client call', description: 'Agenda');
    await manager.addTask(task);
    PickedText? picked;
    await tester.pumpWidget(host(
      manager,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked = await Navigator.of(context).push<PickedText>(
              MaterialPageRoute(builder: (_) => const PickForKeyboardPage(wantItem: true)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client call'));
    await tester.pumpAndSettle();
    expect(picked?.text, 'Client call');
    expect(picked?.task.id, task.id);
  });
}
