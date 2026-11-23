import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart' show ZtLanguages;
import 'package:zero_trust_tasks/components/task_board_view.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_list_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/task_priority.dart';

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String taskId) async {}
}

void main() {
  final now = DateTime(2026, 11, 22, 9);
  final work = TaskList(id: 'work', name: 'Work', createdAt: now, updatedAt: now);
  final mine = TaskList.fallbackDefault;

  group('columns', () {
    final a = Task.create(title: 'A');
    final b = Task.create(title: 'B').withInProgress(true);
    final c = Task.create(title: 'C').copyWith(isCompleted: true);
    final d = Task.create(title: 'D', priority: TaskPriority.high).copyWith(listId: 'work');
    final e = Task.create(title: 'E').copyWith(listId: 'gone');

    test('by status: to do, in progress, done', () {
      final cols = boardColumns([a, b, c, d], BoardGrouping.status, lists: [mine, work]);
      expect(cols.map((c) => c.key), ['todo', 'doing', 'done']);
      expect(cols.map((c) => c.tasks.map((t) => t.title).toList()), [
        ['A', 'D'],
        ['B'],
        ['C'],
      ]);
    });

    test('a done task is never in progress', () {
      expect(b.copyWith(isCompleted: true).inProgress, isFalse);
    });

    test('by list: a task whose list is gone is in My Tasks', () {
      final cols = boardColumns([a, d, e], BoardGrouping.list, lists: [mine, work]);
      expect(cols.map((c) => c.title), ['My Tasks', 'Work']);
      expect(cols.first.tasks.map((t) => t.title), ['A', 'E']);
      expect(cols.last.tasks.single.title, 'D');
    });

    test('by priority, every level is a column', () {
      final cols = boardColumns([a, d], BoardGrouping.priority, lists: const []);
      expect(cols.map((c) => c.key), TaskPriority.values.map((p) => p.name));
    });
  });

  group('drops', () {
    test('into In progress marks it; back to To do clears it', () {
      final t = Task.create(title: 'Write');
      final doing = boardDrop(t, BoardGrouping.status, 'doing', now)!;
      expect(doing.inProgress, isTrue);
      expect(doing.extra[TaskBoardStatus.key], 'doing');
      final back = boardDrop(doing, BoardGrouping.status, 'todo', now)!;
      expect(back.inProgress, isFalse);
      expect(back.extra.containsKey(TaskBoardStatus.key), isFalse);
      expect(boardDrop(back, BoardGrouping.status, 'todo', now), isNull);
    });

    test('by due date: Today keeps the time, No date clears it', () {
      final t = Task.create(title: 'Call', dueDate: DateTime(2026, 11, 30, 14, 15));
      expect(boardDrop(t, BoardGrouping.due, 'today', now)!.dueDate, DateTime(2026, 11, 22, 14, 15));
      expect(boardDrop(t, BoardGrouping.due, 'upcoming', now), isNull);
      expect(boardDrop(t, BoardGrouping.due, 'noDueDate', now)!.dueDate, isNull);
      final undated = Task.create(title: 'Someday');
      expect(boardDrop(undated, BoardGrouping.due, 'upcoming', now)!.dueDate, DateTime(2026, 11, 23));
    });

    test('by priority sets it', () {
      final t = Task.create(title: 'X');
      expect(boardDrop(t, BoardGrouping.priority, 'critical', now)!.priority, TaskPriority.critical);
      expect(boardDrop(t, BoardGrouping.priority, t.priority.name, now), isNull);
    });
  });

  testWidgets('dragging a card to Done completes it, columns side by side', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final writer = MemoryWriter();
    final manager = TaskManager(reminders: false)..attach(writer: writer);
    final lists = TaskListProvider()..attach(save: (_) async {}, delete: (_) async {});
    final task = Task.create(title: 'Write the report');
    await manager.addTask(task);
    var grouping = BoardGrouping.status;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskManagerProvider.overrideWith((ref) => manager),
          taskListProvider.overrideWith((ref) => lists),
          remindersEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('he')],
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Consumer(
                builder: (context, ref, _) => TaskBoardView(
                  tasks: ref.watch(taskManagerProvider).tasks,
                  grouping: grouping,
                  onGroupingChanged: (g) => setState(() => grouping = g),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final todo = tester.getTopLeft(find.text('To do'));
    final doing = tester.getTopLeft(find.text('In progress'));
    final done = tester.getTopLeft(find.text('Completed'));
    expect(todo.dy, doing.dy);
    expect(todo.dx, lessThan(doing.dx));
    expect(doing.dx, lessThan(done.dx));
    // The card sits under its column's title.
    final card = tester.getCenter(find.text('Write the report'));
    expect(card.dy, greaterThan(todo.dy));
    expect(card.dx, lessThan(doing.dx));

    final gesture = await tester.startGesture(card);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Completed')) + const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(manager.tasks.single.isCompleted, isTrue);
    expect(tester.getCenter(find.text('Write the report')).dx, greaterThan(done.dx - 10));

    // Switching to priority columns.
    await tester.tap(find.text('Priority'));
    await tester.pumpAndSettle();
    expect(grouping, BoardGrouping.priority);
  });
}
