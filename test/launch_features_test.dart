import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/core/services/google_tasks_import.dart';
import 'package:zero_trust_tasks/core/services/home_widget_service.dart';
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/globals/task_list_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/models/task_sort_option.dart';

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String taskId) async {}
}

Task task(String title, {String? listId, double? position, DateTime? created, DateTime? due}) => Task(
      id: title.toLowerCase(),
      title: title,
      listId: listId,
      position: position,
      dueDate: due,
      createdAt: created ?? DateTime(2026, 1, 1),
      updatedAt: created ?? DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task JSON stays readable by earlier versions', () {
    test('new keys are written only when set', () {
      final json = task('Plain').toJson();
      expect(json.containsKey('listId'), isFalse);
      expect(json.containsKey('starred'), isFalse);
      expect(json.containsKey('position'), isFalse);
    });

    test('round trip keeps lists, stars, order and unknown keys', () {
      final json = {
        ...task('A', listId: 'l1', position: 2048).toJson(),
        'starred': true,
        'fromTheFuture': {'x': 1},
      };
      final back = Task.fromJson(json);
      expect(back.listId, 'l1');
      expect(back.starred, isTrue);
      expect(back.position, 2048);
      expect(back.toJson()['fromTheFuture'], {'x': 1});
      expect(back.copyWith(title: 'B').toJson()['fromTheFuture'], {'x': 1});
    });
  });

  group('TaskManager', () {
    late TaskManager manager;
    late MemoryWriter writer;
    late StreamController<List<Task>> source;

    setUp(() async {
      manager = TaskManager(reminders: false);
      writer = MemoryWriter();
      source = StreamController<List<Task>>();
      manager.attach(source: () => source.stream, writer: writer);
      source.add([
        task('One', created: DateTime(2026, 1, 1)),
        task('Two', created: DateTime(2026, 1, 2)),
        task('Three', created: DateTime(2026, 1, 3)),
        task('Other', listId: 'work'),
      ]);
      await pumpEventQueue();
    });

    tearDown(() => manager.dispose());

    test('stars and moves tasks between lists', () async {
      await manager.toggleStar('one');
      expect(writer.saved['one']!.starred, isTrue);
      await manager.moveToList({'one', 'two'}, 'work');
      expect(writer.saved['two']!.listId, 'work');
      await manager.moveToList({'one'}, TaskList.defaultId);
      expect(writer.saved['one']!.listId, isNull);
    });

    test('drag to reorder gives the whole list positions', () async {
      final ordered = manager.openTasksInOrder(listId: TaskList.defaultId);
      expect(ordered.map((t) => t.title), ['One', 'Two', 'Three']);
      await manager.reorder(ordered, 2, 0); // Three to the top
      final after = manager.openTasksInOrder(listId: TaskList.defaultId);
      expect(after.map((t) => t.title), ['Three', 'One', 'Two']);
      expect(
        TaskFilterService.sortTasks(manager.tasks.where((t) => t.listId == null).toList(), TaskSortOption.manual)
            .map((t) => t.title),
        ['Three', 'One', 'Two'],
      );
    });

    test('indent into a subtask and back out', () async {
      await manager.makeSubtaskOf('two', 'one');
      final one = manager.tasks.firstWhere((t) => t.id == 'one');
      expect(one.subTasks.single.title, 'Two');
      expect(manager.tasks.firstWhere((t) => t.id == 'two').deletedAt, isNotNull, reason: 'in trash, restorable');

      final promoted = await manager.promoteSubTask('one', one.subTasks.single.id);
      expect(promoted!.title, 'Two');
      expect(manager.tasks.firstWhere((t) => t.id == 'one').subTasks, isEmpty);
    });

    test('deleting a list sends its tasks to trash', () async {
      expect(await manager.trashList('work'), 1);
      expect(writer.saved['other']!.deletedAt, isNotNull);
    });

    test('a failed save keeps later actions; done ones are not replayed', () async {
      final repeating = task('Daily').copyWith(
        dueDate: DateTime(2026, 1, 1),
        recurrence: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      source.add([...manager.tasks, repeating]);
      await pumpEventQueue();
      final done = <String>[];
      final actions = [
        PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'daily', at: DateTime.now()),
        PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'one', at: DateTime.now()),
      ];
      var calls = 0;
      await expectLater(
        manager.applyPendingActions(actions, onDone: (a) async {
          if (++calls == 2) throw StateError('locked');
          done.add(a.taskId);
        }),
        throwsStateError,
      );
      expect(done, ['daily'], reason: 'the repeating task is acknowledged before the next action');
      expect(writer.saved['daily']!.dueDate, DateTime(2026, 1, 2));
    });

    test('applies Complete and Snooze taps made while locked', () async {
      final until = DateTime.now().add(const Duration(hours: 1));
      final changed = await manager.applyPendingActions([
        PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'one', at: DateTime.now()),
        PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'one', at: DateTime.now()),
        PendingTaskAction(type: PendingTaskActionType.snooze, taskId: 'two', until: until, at: DateTime.now()),
        PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'gone', at: DateTime.now()),
      ]);
      expect(changed, 2, reason: 'a second Complete and an unknown task are skipped');
      expect(writer.saved['one']!.isCompleted, isTrue);
      expect(writer.saved['two']!.reminderAt, until);
    });
  });

  test('pending actions survive a round trip through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PendingActionsStore();
    await store.add(PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'a', at: DateTime(2026, 1, 1)));
    await store.add(PendingTaskAction(
      type: PendingTaskActionType.snooze,
      taskId: 'b',
      until: DateTime(2026, 1, 1, 10),
      at: DateTime(2026, 1, 2),
    ));
    final taken = await store.pending();
    expect(taken.map((a) => (a.type, a.taskId)), [
      (PendingTaskActionType.complete, 'a'),
      (PendingTaskActionType.snooze, 'b'),
    ]);
    expect(taken.last.until, DateTime(2026, 1, 1, 10));
    // Not applied yet (say the vault locked): still there.
    expect(await store.pending(), hasLength(2));
    // A tap arriving meanwhile survives the acknowledgement of the others.
    await store.add(PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'c', at: DateTime(2026, 1, 3)));
    await store.acknowledge(taken);
    expect((await store.pending()).map((a) => a.taskId), ['c']);
  });

  test('the default list is always there and can be renamed', () async {
    final lists = TaskListProvider();
    final saved = <TaskList>[];
    lists.attach(source: const Stream.empty(), save: (l) async => saved.add(l), delete: (_) async {});
    expect(lists.lists.single.name, 'My Tasks');
    expect(lists.isLoaded, isFalse, reason: 'nothing read yet');
    await lists.save(lists.byId(null).copyWith(name: 'Inbox'));
    final work = await lists.create('Work');
    expect(lists.lists.map((l) => l.name), ['Inbox', 'Work']);
    expect(lists.byId('deleted-elsewhere').isDefault, isTrue);
    expect(saved.map((l) => l.id), [TaskList.defaultId, work.id]);
    expect(() => lists.remove(TaskList.defaultId), throwsStateError);
    lists.dispose();
  });

  group('Google Tasks import', () {
    final takeout = {
      'kind': 'tasks#taskLists',
      'items': [
        {
          'kind': 'tasks#taskList',
          'id': 'L1',
          'title': 'My Tasks',
          'items': [
            {'id': 't2', 'title': 'Second', 'status': 'needsAction', 'position': '00000000000000000001'},
            {
              'id': 't1',
              'title': 'First',
              'notes': 'with notes',
              'status': 'needsAction',
              'due': '2026-03-05T00:00:00.000Z',
              'position': '00000000000000000000',
            },
            {'id': 's1', 'title': 'Sub', 'status': 'completed', 'parent': 't1', 'position': '0'},
            {'id': 'gone', 'title': 'Deleted', 'deleted': true},
          ],
        },
        {
          'kind': 'tasks#taskList',
          'id': 'L2',
          'title': 'Shopping',
          'items': [
            {'id': 't3', 'title': 'Milk', 'status': 'completed', 'completed': '2026-02-01T10:00:00.000Z'},
          ],
        },
      ],
    };

    test('reads lists, notes, due dates, subtasks and order', () {
      final result = const GoogleTasksImporter().parse(
        Uint8List.fromList(utf8.encode(jsonEncode(takeout))),
        existingLists: [TaskList.fallbackDefault],
      );
      expect(result.lists.single.name, 'Shopping');
      expect(result.skipped, 1);
      final byTitle = {for (final t in result.tasks) t.title: t};
      expect(byTitle.keys, ['First', 'Second', 'Milk']);
      expect(byTitle['First']!.listId, isNull, reason: 'Google "My Tasks" is the default list');
      expect(byTitle['First']!.description, 'with notes');
      expect(byTitle['First']!.dueDate, DateTime(2026, 3, 5));
      expect(byTitle['First']!.subTasks.single.title, 'Sub');
      expect(byTitle['First']!.subTasks.single.isCompleted, isTrue);
      expect(byTitle['Milk']!.listId, result.lists.single.id);
      expect(byTitle['Milk']!.isCompleted, isTrue);
    });

    test('reads the Takeout zip, matches lists by name, same ids each time', () {
      final json = utf8.encode(jsonEncode(takeout));
      final archive = Archive()..addFile(ArchiveFile('Takeout/Tasks/Tasks.json', json.length, json));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));
      final shopping = TaskList.create(name: 'shopping');
      final a = const GoogleTasksImporter().parse(zip, existingLists: [TaskList.fallbackDefault, shopping]);
      final b = const GoogleTasksImporter().parse(zip, existingLists: [TaskList.fallbackDefault, shopping]);
      expect(a.lists, isEmpty);
      expect(a.tasks.firstWhere((t) => t.title == 'Milk').listId, shopping.id);
      expect(a.tasks.map((t) => t.id), b.tasks.map((t) => t.id));
    });

    test('says so when the file is something else', () {
      expect(
        () => const GoogleTasksImporter().parse(Uint8List.fromList(utf8.encode('{"foo": 1}')), existingLists: []),
        throwsA(isA<GoogleTasksImportException>()),
      );
    });
  });

  group('home-screen widget', () {
    final now = DateTime(2026, 5, 10, 9);
    final tasks = [
      task('Today', due: DateTime(2026, 5, 10, 18)),
      task('Late', due: DateTime(2026, 5, 8)),
      task('Someday'),
      task('Work thing', listId: 'work'),
    ];

    test('shows only counts unless titles are turned on', () {
      final content = HomeWidgetService.contentFor(tasks: tasks, list: null, showTasks: false, now: now);
      expect(content.rows, isEmpty);
      expect(content.title, 'All tasks');
      expect(content.summary, '4 open · 1 due today · 1 overdue');
    });

    test('with titles: soonest first, limited to the chosen list', () {
      final all = HomeWidgetService.contentFor(tasks: tasks, list: null, showTasks: true, now: now);
      expect(all.rows.map((r) => r.title), ['Late', 'Today', 'Someday', 'Work thing']);
      expect(all.rows.first.due, 'Overdue · Fri 8 May');
      expect(all.rows[1].due, 'Today');

      final work = TaskList.create(name: 'Work');
      final scoped = HomeWidgetService.contentFor(
        tasks: [...tasks, task('Other work', listId: work.id)],
        list: work,
        showTasks: true,
        now: now,
      );
      expect(scoped.title, 'Work');
      expect(scoped.rows.map((r) => r.title), ['Other work']);

      // A task whose list was deleted shows in the default list.
      final mine = HomeWidgetService.contentFor(
        tasks: [task('Orphan', listId: 'deleted')],
        list: TaskList.fallbackDefault,
        showTasks: true,
        now: now,
        resolveList: (id) => id == null || id == 'deleted' ? TaskList.defaultId : id,
      );
      expect(mine.rows.map((r) => r.title), ['Orphan']);
    });

    test('Today shows tasks due today and overdue; Starred only starred ones', () {
      final starred = task('Star').copyWith(starred: true);
      final today = HomeWidgetService.contentFor(
        tasks: [...tasks, starred],
        list: null,
        showTasks: true,
        now: now,
        filter: WidgetFilter.today,
      );
      expect(today.title, 'Today');
      expect(today.rows.map((r) => r.title), ['Late', 'Today']);
      expect(today.summary, '2 open · 1 due today · 1 overdue');

      final star = HomeWidgetService.contentFor(
        tasks: [...tasks, starred],
        list: null,
        showTasks: true,
        now: now,
        filter: WidgetFilter.starred,
      );
      expect(star.title, 'Starred');
      expect(star.rows.map((r) => r.title), ['Star']);
    });

    test('with details off no scope has titles or list names', () {
      final work = TaskList.create(name: 'Secret project');
      final scopes = HomeWidgetService.scopesFor(
        tasks: [...tasks, task('Plan', listId: work.id)],
        lists: [TaskList.fallbackDefault, work],
        showTasks: false,
        now: now,
      );
      expect(scopes.keys, ['all', 'today', 'starred', 'list:default', 'list:${work.id}']);
      for (final content in scopes.values) {
        expect(content.rows, isEmpty);
      }
      expect(scopes.toString(), isNot(contains('Secret project')));
      expect(scopes['list:${work.id}']!.title, 'All tasks');
      expect(scopes['today']!.title, 'Today');
    });

    test('every scope at once, in the form the widget reads', () {
      final work = TaskList.create(name: 'Work');
      final scopes = HomeWidgetService.scopesFor(
        tasks: [...tasks, task('Plan', listId: work.id)],
        lists: [TaskList.fallbackDefault, work],
        showTasks: true,
        now: now,
      );
      expect(scopes['list:${work.id}']!.toJson(), {
        't': 'Work',
        's': '1 open · 1 due today · 1 overdue',
        'r': [
          {'id': 'plan', 't': 'Plan'},
        ],
      });
      expect(scopes['today']!.toJson()['r'], [
        {'id': 'late', 't': 'Late', 'd': 'Overdue · Fri 8 May'},
        {'id': 'today', 't': 'Today', 'd': 'Today'},
      ]);
      expect(HomeWidgetService.scopeKey(WidgetFilter.list), 'all');
      expect(HomeWidgetService.scopeKey(WidgetFilter.list, 'x'), 'list:x');
    });

    test("tomorrow's scopes, for after midnight: Today moves on a day", () {
      final tomorrow = HomeWidgetService.scopesFor(
        tasks: [...tasks, task('Next', due: DateTime(2026, 5, 11, 8)), task('Later', due: DateTime(2026, 5, 13))],
        lists: const [],
        showTasks: true,
        now: DateTime(2026, 5, 11),
      );
      expect(tomorrow['today']!.rows.map((r) => r.title), ['Late', 'Today', 'Next']);
      expect(tomorrow['today']!.rows[1].due, 'Overdue · Sun 10 May');
      expect(tomorrow['today']!.summary, '3 open · 1 due today · 2 overdue');
      expect(HomeWidgetService.dayKey(DateTime(2026, 5, 9, 23, 59)), '2026-05-09');
    });
  });

  test('subtask JSON unchanged', () {
    expect(SubTask(id: 'x', title: 'y').toJson(), {'id': 'x', 'title': 'y', 'isCompleted': false});
  });
}
