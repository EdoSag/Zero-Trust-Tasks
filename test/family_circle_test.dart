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

  test('a shown list and its open and recently done tasks, in the format the '
      'family hub reads', () {
    final items = FamilyCircleLists.itemsFor('circle-1', [groceries, work], tasks, inList, now);
    expect(items.keys.toSet(), {'tasks/list/groceries', 'tasks/item/milk', 'tasks/item/eggs'});
    for (final id in items.keys) {
      expect(ZtFamilySpace.appOf(id), 'tasks');
    }
    final l = ZtFamilySummary.of(items['tasks/list/groceries'])!;
    expect((l.title, l.kind), ('Groceries', 'tasks.list'));
    final milk = ZtFamilySummary.of(items['tasks/item/milk'])!;
    expect((milk.title, milk.kind, milk.done, milk.list), ('Milk', 'tasks.item', false, 'tasks/list/groceries'));
    expect(milk.due, DateTime(2026, 1, 11).toUtc());
    expect(ZtFamilySummary.of(items['tasks/item/eggs'])!.done, isTrue);

    // Another circle, or no circle: nothing.
    expect(FamilyCircleLists.itemsFor('circle-2', [groceries, work], tasks, inList, now), isEmpty);
  });

  test('only changes are written; tasks that left my shown list go, other '
      'people\'s lists and other apps\' items stay', () {
    final want = FamilyCircleLists.itemsFor('circle-1', [groceries, work], tasks, inList, now);
    LocalItem item(String id, Map<String, Object?>? json) => LocalItem(itemId: id, updatedAt: now, json: json);
    final movedAway = ZtFamilySummary(title: 'Soap', kind: 'tasks.item', list: 'tasks/list/groceries')
        .addTo({'kind': 'tasks.item'});
    final someoneElses = ZtFamilySummary(title: 'Mop', kind: 'tasks.item', list: 'tasks/list/their-chores')
        .addTo({'kind': 'tasks.item'});
    final r = FamilyCircleLists.diff(
      existing: [
        item('tasks/list/groceries', want['tasks/list/groceries']),
        item('tasks/item/milk', {...want['tasks/item/milk']!, 'title': 'Milk (old)'}),
        item('tasks/item/soap', movedAway),
        item('tasks/item/mop', someoneElses),
        item('tasks/list/their-chores', {'kind': 'tasks.list'}),
        item('meds/dose/x.1', {'kind': 'meds.dose'}),
        item('family.circle', {'kind': 'family.circle'}),
      ],
      want: want,
      mine: {'tasks/list/groceries', 'tasks/list/work', 'tasks/list/default'},
    );
    expect(r.save.keys.toSet(), {'tasks/item/milk', 'tasks/item/eggs'});
    expect(r.delete, {'tasks/item/soap'});

    // Switched off: the list and all its tasks go.
    final off = FamilyCircleLists.diff(
      existing: [for (final e in want.entries) item(e.key, e.value)],
      want: const {},
      mine: {'tasks/list/groceries'},
    );
    expect(off.delete, want.keys.toSet());
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
      want: FamilyCircleLists.itemsFor(circle.id, [shown], tasks, inList, now),
      mine: {'tasks/list/groceries'},
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
    expect(seen.keys.toSet(), {'tasks/list/groceries', 'tasks/item/milk', 'tasks/item/eggs'});
    expect(seen['tasks/item/milk']!.list, 'tasks/list/groceries');
  });
}
