import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/core/services/other_apps_import.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/task_priority.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  final now = DateTime(2026, 11, 22, 12);
  const importer = OtherAppsImporter();
  final work = TaskList(id: 'work-id', name: 'Work', createdAt: now, updatedAt: now);

  group('Todoist', () {
    const csv = 'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,DATE_LANG,TIMEZONE,DURATION,DURATION_UNIT,DEADLINE,DEADLINE_LANG\n'
        'section,Errands,,,,,,,,,,,,\n'
        'task,Buy milk,"2%, not skim",1,1,Edo,,2026-11-24,en,Asia/Jerusalem,,,,\n'
        'task,Get oat milk too,,4,2,Edo,,,,,,,,\n'
        'note,Ask for the big bottle,,,,,,,,,,,,\n'
        'task,Water plants,,3,1,Edo,,every monday,en,,,,2026-12-01,en\n'
        'task,,,4,1,,,,,,,,,\n';

    test('a project CSV becomes a list, with subtasks, sections as tags and comments', () {
      final r = importer.parse(bytes(csv), fileName: 'Home [2203306141].csv', existingLists: [work], now: now);
      expect(r.source, ImportSource.todoist);
      expect(r.lists.single.name, 'Home');
      expect(r.skipped, 1);
      expect(r.tasks.map((t) => t.title), ['Buy milk', 'Water plants']);
      final milk = r.tasks.first;
      expect(milk.listId, r.lists.single.id);
      expect(milk.priority, TaskPriority.critical);
      expect(milk.dueDate, DateTime(2026, 11, 24));
      expect(milk.tags, ['Errands']);
      expect(milk.subTasks.single.title, 'Get oat milk too');
      expect(milk.description, '2%, not skim\n\nAsk for the big bottle');
      final plants = r.tasks.last;
      expect(plants.priority, TaskPriority.medium);
      // The deadline is the due date; a recurring date is kept as text.
      expect(plants.dueDate, DateTime(2026, 12, 1));
      expect(plants.description, 'every monday');
    });

    test('importing the same file twice gives the same ids', () {
      final a = importer.parse(bytes(csv), fileName: 'Home.csv', existingLists: [work], now: now);
      final b = importer.parse(bytes(csv), fileName: 'Home.csv', existingLists: [work], now: now);
      expect(a.tasks.map((t) => t.id), b.tasks.map((t) => t.id));
      expect(a.lists.single.id, b.lists.single.id);
    });

    test('a backup .zip of projects; Inbox goes to My Tasks, Work to the existing list', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('Inbox [1].csv', bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Call mum,4,1\n')))
        ..addFile(ArchiveFile.bytes('Work [2].csv', bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Send report,2,1\n')));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));
      final r = importer.parse(zip, fileName: 'backup.zip', existingLists: [work], now: now);
      expect(r.lists, isEmpty);
      expect({for (final t in r.tasks) t.title: t.listId}, {'Call mum': null, 'Send report': 'work-id'});
    });
  });

  group('Review fixes', () {
    test('two projects with the same name keep their tasks apart', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('Work [123].csv', bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,4,1\n')))
        ..addFile(ArchiveFile.bytes('Work [456].csv', bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,2,1\n')));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));
      final r = importer.parse(zip, fileName: 'backup.zip', existingLists: [work], now: now);
      expect(r.tasks.map((t) => t.id).toSet(), hasLength(2));
      expect(r.tasks.every((t) => t.listId == 'work-id'), isTrue);
      // A single project keeps the ids earlier versions gave it.
      final one = importer.parse(bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,4,1\n'), fileName: 'Work [123].csv', existingLists: [work], now: now);
      final again = Archive()..addFile(ArchiveFile.bytes('Work [123].csv', bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,4,1\n')));
      final fromZip = importer.parse(Uint8List.fromList(ZipEncoder().encode(again)), existingLists: [work], now: now);
      expect(fromZip.tasks.single.id, one.tasks.single.id);
    });

    test('a shared list with the same name is never matched', () {
      final shared = TaskList(
        id: TaskList.sharedId('space-1'),
        name: 'Work',
        createdAt: now,
        updatedAt: now,
        shared: const SharedListInfo(spaceId: 'space-1'),
      );
      final r = importer.parse(bytes('TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,4,1\n'), fileName: 'Work.csv', existingLists: [shared], now: now);
      expect(r.lists.single.name, 'Work');
      expect(r.lists.single.isShared, isFalse);
      expect(r.tasks.single.listId, r.lists.single.id);
    });

    test('each task carries the fingerprint of what the source said', () {
      const a = 'TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,4,1\n';
      const b = 'TYPE,CONTENT,PRIORITY,INDENT\ntask,Plan,1,1\n';
      final first = importer.parse(bytes(a), fileName: 'Home.csv', existingLists: [], now: now).tasks.single;
      final later = importer.parse(bytes(a), fileName: 'Home.csv', existingLists: [], now: now.add(const Duration(days: 3))).tasks.single;
      final changed = importer.parse(bytes(b), fileName: 'Home.csv', existingLists: [], now: now).tasks.single;
      final key = OtherAppsImporter.importedAsKey;
      expect(first.extra[key], isA<String>());
      expect(later.extra[key], first.extra[key]);
      expect(changed.extra[key], isNot(first.extra[key]));
    });
  });

  group('Microsoft To Do', () {
    final json = jsonEncode({
      'lists': [
        {
          'id': 'L1',
          'displayName': 'Tasks',
          'wellknownListName': 'defaultList',
          'tasks': [
            {
              'id': 'T1',
              'title': 'Renew passport',
              'status': 'notStarted',
              'importance': 'high',
              'body': {'content': '<p>Bring photos</p>', 'contentType': 'html'},
              'dueDateTime': {'dateTime': '2026-12-03T00:00:00.0000000', 'timeZone': 'UTC'},
              'checklistItems': [
                {'id': 'C1', 'displayName': 'Fill in the form', 'isChecked': true},
                {'id': 'C2', 'displayName': 'Pay the fee', 'isChecked': false},
              ],
              'categories': ['Admin'],
            },
            {'id': 'T2', 'title': '', 'status': 'notStarted'},
          ],
        },
        {
          'id': 'L2',
          'displayName': 'Groceries',
          'tasks': [
            {'id': 'T3', 'title': 'Eggs', 'status': 'completed', 'completedDateTime': {'dateTime': '2026-11-20T10:00:00', 'timeZone': 'UTC'}},
          ],
        },
      ],
    });

    test('lists, steps, importance, due day and done tasks', () {
      final r = importer.parse(bytes(json), fileName: 'todo.json', existingLists: const [], now: now);
      expect(r.source, ImportSource.microsoftToDo);
      expect(r.skipped, 1);
      expect(r.lists.single.name, 'Groceries');
      final passport = r.tasks.first;
      expect(passport.listId, isNull);
      expect(passport.priority, TaskPriority.high);
      expect(passport.starred, isTrue);
      expect(passport.description, 'Bring photos');
      expect(passport.dueDate, DateTime(2026, 12, 3));
      expect(passport.tags, ['Admin']);
      expect(passport.subTasks.map((s) => (s.title, s.isCompleted)), [('Fill in the form', true), ('Pay the fee', false)]);
      final eggs = r.tasks.last;
      expect(eggs.isCompleted, isTrue);
      expect(eggs.completedAt, DateTime.utc(2026, 11, 20, 10).toLocal());
      expect(eggs.listId, r.lists.single.id);
    });
  });

  group('TickTick', () {
    const csv = '"Date: 2026-11-22+0200"\n'
        '"Version: 7.1"\n'
        '"Status: \n0 Normal\n1 Completed\n2 Archived"\n'
        '"Folder Name","List Name","Title","Kind","Tags","Content","Is Check list","Start Date","Due Date","Reminder","Repeat","Priority","Status","Created Time","Completed Time","Order","Timezone","Is All Day","Is Floating","Column Name","Column Order","View Mode","taskId","parentId"\n'
        '"","Inbox","Pack for trip","CHECKLIST","travel,family","Don\'t forget\n▫Passport\n▪Charger","Y","","2026-11-30T22:00:00+0000","","","5","0","2026-11-01T08:00:00+0000","","1","Asia/Jerusalem","true","false","","","list","100",""\n'
        '"","Inbox","Book taxi","TEXT","","","N","","","","","0","0","2026-11-01T08:00:00+0000","","2","Asia/Jerusalem","false","false","","","list","101","100"\n'
        '"","Home","Fix tap","TEXT","","","N","","2026-11-25T07:30:00+0000","","","3","2","2026-11-02T08:00:00+0000","2026-11-03T08:00:00+0000","1","Asia/Jerusalem","false","false","","","list","102",""\n'
        '"","Home","Old idea","TEXT","","","N","","","","","0","-1","2026-11-02T08:00:00+0000","","2","","false","false","","","list","103",""\n';

    test('backup rows become tasks, with checklist items and subtasks as steps', () {
      final r = importer.parse(bytes(csv), fileName: 'TickTick-backup.csv', existingLists: const [], now: now);
      expect(r.source, ImportSource.tickTick);
      expect(r.skipped, 1);
      expect(r.lists.single.name, 'Home');
      expect(r.tasks.map((t) => t.title), ['Pack for trip', 'Fix tap']);
      final pack = r.tasks.first;
      expect(pack.listId, isNull);
      expect(pack.priority, TaskPriority.high);
      expect(pack.tags, ['travel', 'family']);
      expect(pack.description, "Don't forget");
      expect(pack.subTasks.map((s) => (s.title, s.isCompleted)), [
        ('Passport', false),
        ('Charger', true),
        ('Book taxi', false),
      ]);
      // An all-day due date keeps its day.
      final dueLocal = DateTime.utc(2026, 11, 30, 22).toLocal();
      expect(pack.dueDate, DateTime(dueLocal.year, dueLocal.month, dueLocal.day));
      final tap = r.tasks.last;
      expect(tap.isCompleted, isTrue);
      expect(tap.dueDate, DateTime.utc(2026, 11, 25, 7, 30).toLocal());
      expect(tap.priority, TaskPriority.medium);
    });
  });

  test('anything else is turned away', () {
    expect(
      () => importer.parse(bytes('name,phone\nDana,050\n'), existingLists: const [], now: now),
      throwsA(isA<OtherAppsImportException>().having((e) => e.problem, 'problem', ImportProblem.notRecognised)),
    );
    expect(
      () => importer.parse(bytes('TYPE,CONTENT\n'), fileName: 'x.csv', existingLists: const [], now: now),
      throwsA(isA<OtherAppsImportException>().having((e) => e.problem, 'problem', ImportProblem.empty)),
    );
  });
}
