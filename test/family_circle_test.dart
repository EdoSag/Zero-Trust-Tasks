import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/suite/family_circle.dart';

final now = DateTime(2026, 1, 10, 12);
final created = DateTime(2026, 1, 1);

TaskList list(String id, String name, {String? circle}) {
  final l = TaskList(id: id, name: name, createdAt: created, updatedAt: created);
  return circle == null ? l : l.withFamilyCircle(circle);
}

Task task(
  String id,
  String title, {
  String? listId,
  bool done = false,
  DateTime? completedAt,
  DateTime? due,
  bool archived = false,
  DateTime? deletedAt,
}) =>
    Task(
      id: id,
      title: title,
      listId: listId,
      isCompleted: done,
      completedAt: completedAt,
      dueDate: due,
      isArchived: archived,
      deletedAt: deletedAt,
      createdAt: created,
      updatedAt: created,
    );

bool inList(TaskList l, Task t) => (t.listId ?? TaskList.defaultId) == l.id;

void main() {
  final groceries = list('groceries', 'Groceries', circle: 'circle-1');
  final work = list('work', 'Work');
  final tasks = [
    task('milk', 'Milk', listId: 'groceries', due: DateTime(2026, 1, 11)),
    task('eggs', 'Eggs', listId: 'groceries', done: true, completedAt: DateTime(2026, 1, 9)),
    task('old', 'Bread', listId: 'groceries', done: true, completedAt: DateTime(2025, 12, 1)),
    task('gone', 'Cheese', listId: 'groceries', deletedAt: DateTime(2026, 1, 9)),
    task('arch', 'Jam', listId: 'groceries', archived: true),
    task('report', 'Write report', listId: 'work'),
  ];

  test('the circle survives a save of the list, and can be cleared', () {
    final back = TaskList.fromJson(groceries.toJson());
    expect(back.familyCircle, 'circle-1');
    expect(back.withFamilyCircle(null).familyCircle, isNull);
    expect(work.familyCircle, isNull);
  });

  const me = 'user-a';
  test('a shown list and its open and recently done tasks, in the format the '
      'family hub reads, under my user id', () {
    final items = FamilyCircleLists.itemsFor('circle-1', me, [groceries, work], tasks, inList, now);
    expect(items.keys.toSet(), {'tasks/list/$me/groceries', 'tasks/item/$me/milk', 'tasks/item/$me/eggs'});
    for (final id in items.keys) {
      expect(ZtFamilySpace.appOf(id), 'tasks');
    }
    final l = ZtFamilySummary.of(items['tasks/list/$me/groceries'])!;
    expect((l.title, l.kind), ('Groceries', 'tasks.list'));
    final milk = ZtFamilySummary.of(items['tasks/item/$me/milk'])!;
    expect((milk.title, milk.kind, milk.done, milk.list), ('Milk', 'tasks.item', false, 'tasks/list/$me/groceries'));
    expect(milk.due, DateTime(2026, 1, 11).toUtc());
    expect(ZtFamilySummary.of(items['tasks/item/$me/eggs'])!.done, isTrue);

    // Another circle, or no circle: nothing.
    expect(FamilyCircleLists.itemsFor('circle-2', me, [groceries, work], tasks, inList, now), isEmpty);
  });

  test('only changes are written; my items that are no longer wanted go, '
      'other people\'s (even their "default" list) and other apps\' stay', () {
    final want = FamilyCircleLists.itemsFor('circle-1', me, [groceries, work], tasks, inList, now);
    LocalItem item(String id, Map<String, Object?>? json) => LocalItem(itemId: id, updatedAt: now, json: json);
    final r = FamilyCircleLists.diff(
      existing: [
        item('tasks/list/$me/groceries', want['tasks/list/$me/groceries']),
        item('tasks/item/$me/milk', {...want['tasks/item/$me/milk']!, 'title': 'Milk (old)'}),
        // Moved out of the list, and a list I deleted.
        item('tasks/item/$me/soap', {'kind': 'tasks.item'}),
        item('tasks/list/$me/deleted', {'kind': 'tasks.list'}),
        // Someone else's default list and task.
        item('tasks/list/user-b/default', {'kind': 'tasks.list'}),
        item('tasks/item/user-b/mop', {'kind': 'tasks.item'}),
        item('meds/dose/x.1', {'kind': 'meds.dose'}),
        item('family.circle', {'kind': 'family.circle'}),
      ],
      want: want,
      user: me,
    );
    expect(r.save.keys.toSet(), {'tasks/item/$me/milk', 'tasks/item/$me/eggs'});
    expect(r.delete, {'tasks/item/$me/soap', 'tasks/list/$me/deleted'});

    // Switched off: the list and all its tasks go.
    final off = FamilyCircleLists.diff(
      existing: [for (final e in want.entries) item(e.key, e.value)],
      want: const {},
      user: me,
    );
    expect(off.delete, want.keys.toSet());
    // Someone else with nothing shown removes nothing of mine.
    final theirs = FamilyCircleLists.diff(
      existing: [for (final e in want.entries) item(e.key, e.value)],
      want: const {},
      user: 'user-b',
    );
    expect(theirs.delete, isEmpty);
  });

  test('a circle member writes the list into the circle and it reads back '
      'on the admin\'s phone', () async {
    final server = InMemorySpaceServer();
    const mum = '00000000-0000-4000-8000-00000000000a';
    const dad = '00000000-0000-4000-8000-00000000000b';
    Future<SharedSpaces> circlesOf(String user, int seed) async => SharedSpaces(
          app: ZtFamilySpace.app,
          myUserId: user,
          identity: await ZtIdentity.fromDek(List<int>.generate(32, (i) => (seed * 7 + i) & 0xff)),
          backend: server.backendFor(user),
          privateStore: InMemorySpacePrivateStore(),
          openStore: (_) async => InMemoryItemStore(),
          deleteStore: (_) async {},
          deviceId: 'phone-$user',
          policy: ZtFamilySpace.policy,
        );
    final mumCircles = await circlesOf(mum, 1);
    final dadCircles = await circlesOf(dad, 2);
    final circle = await mumCircles.create(myName: 'Mum');
    await mumCircles.sync(circle);
    final link = await mumCircles.invite(circle.id);
    await dadCircles.answer(SpaceInviteLink.parse(link.toString()), myName: 'Dad');
    await mumCircles.confirm((await mumCircles.pendingJoins(circle.id)).single);

    final dads = await dadCircles.open(circle.id);
    await dadCircles.sync(dads);
    final shown = list('groceries', 'Groceries', circle: circle.id);
    final changes = FamilyCircleLists.diff(
      existing: await dads.store.all(),
      want: FamilyCircleLists.itemsFor(circle.id, dad, [shown], tasks, inList, now),
      user: dad,
    );
    for (final e in changes.save.entries) {
      await dads.save(e.key, e.value);
    }
    await dadCircles.sync(dads);
    await mumCircles.sync(circle);
    final seen = {
      for (final i in await circle.store.all())
        if (ZtFamilySpace.appOf(i.itemId) == 'tasks') i.itemId: ZtFamilySummary.of(i.json)!,
    };
    expect(seen.keys.toSet(), {'tasks/list/$dad/groceries', 'tasks/item/$dad/milk', 'tasks/item/$dad/eggs'});
    expect(seen['tasks/item/$dad/milk']!.list, 'tasks/list/$dad/groceries');
  });
}
