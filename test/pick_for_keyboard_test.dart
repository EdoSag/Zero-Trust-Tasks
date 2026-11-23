import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages;
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/l10n/generated/app_l10n_en.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/pages/pick_for_keyboard_page.dart';

class MemoryWriter implements TaskWriter {
  @override
  Future<void> save(Task task) async {}
  @override
  Future<void> delete(String taskId) async {}
}

void main() {
  final dentist = Task.create(
    title: 'Call the dentist',
    dueDate: DateTime(2026, 11, 24, 10, 30),
    links: ['https://dentist.example'],
  );
  final shopping = Task.create(
    title: 'Shopping',
    dueDate: DateTime(2026, 11, 23),
    subTasks: [SubTask(id: 'a', title: 'Milk'), SubTask(id: 'b', title: 'Bread', isCompleted: true)],
  );
  final someday = Task.create(title: 'Read a book', description: 'Something by Amos Oz');
  final done = Task.create(title: 'Pay the dentist bill').copyWith(isCompleted: true);
  final archived = Task.create(title: 'Old dentist note').copyWith(isArchived: true);
  final trashed = Task.create(title: 'Trashed dentist').copyWith(deletedAt: DateTime(2026, 11, 1));
  final all = [someday, dentist, done, archived, trashed, shopping];

  test('offers open tasks, soonest due first, undated last', () {
    expect(pickTasks(all, '').map((t) => t.title), ['Shopping', 'Call the dentist', 'Read a book']);
  });

  test('a search finds done tasks too, open first, never archived or trashed', () {
    expect(pickTasks(all, 'DENTIST').map((t) => t.title), ['Call the dentist', 'Pay the dentist bill']);
    expect(pickTasks(all, 'amos').single.title, 'Read a book');
    expect(pickTasks(all, 'milk').single.title, 'Shopping');
    expect(pickTasks(all, 'zzz'), isEmpty);
  });

  test('a task offers its title, due date, checklist and links', () {
    final l = AppL10nEn();
    expect(pickValues(dentist, l).map((v) => v.$3), [
      'Call the dentist',
      'Tuesday, November 24, 2026, 10:30',
      'Call the dentist, Tuesday, November 24, 2026, 10:30',
      'https://dentist.example',
    ]);
    expect(pickValues(shopping, l).map((v) => v.$3), [
      'Shopping',
      'Monday, November 23, 2026',
      'Shopping, Monday, November 23, 2026',
      'Shopping\n☐ Milk\n☑ Bread',
    ]);
  });

  testWidgets('tapping a task, then a value, pops with that text', (tester) async {
    final manager = TaskManager(reminders: false)..attach(writer: MemoryWriter());
    for (final t in [someday, dentist, shopping]) {
      await manager.addTask(t);
    }
    String? picked = 'unset';
    String? pickedId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskManagerProvider.overrideWith((ref) => manager),
          remindersEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('he')],
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final r = await Navigator.of(
                    context,
                  ).push<PickedText>(MaterialPageRoute(builder: (_) => const PickForKeyboardPage()));
                  picked = r?.text;
                  pickedId = r?.task.id;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Insert into ZT Keyboard'), findsOneWidget);
    // Soonest first, on screen in that order.
    final shoppingY = tester.getTopLeft(find.text('Shopping')).dy;
    final dentistY = tester.getTopLeft(find.text('Call the dentist')).dy;
    final bookY = tester.getTopLeft(find.text('Read a book')).dy;
    expect(shoppingY, lessThan(dentistY));
    expect(dentistY, lessThan(bookY));

    await tester.tap(find.text('Call the dentist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('https://dentist.example'));
    await tester.pumpAndSettle();
    expect(picked, 'https://dentist.example');
    expect(pickedId, dentist.id);

    // A search, then a task with a title and a description: a sheet asks which.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'book');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read a book'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    await tester.tap(find.text('Something by Amos Oz'));
    await tester.pumpAndSettle();
    expect(picked, 'Something by Amos Oz');
  });
}
