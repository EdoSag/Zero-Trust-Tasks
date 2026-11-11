import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/sharing/shared_list_pages.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';

const alice = '00000000-0000-4000-8000-00000000000a';
const bob = '00000000-0000-4000-8000-00000000000b';

Uint8List key(int seed) => Uint8List.fromList(List<int>.generate(32, (i) => (seed * 7 + i) & 0xff));

/// The account's notes about spaces, kept in its own (in-memory) vault
/// store, where the app reads which shared lists it belongs to.
class StorePrivate implements SpacePrivateStore {
  StorePrivate(this.store);
  final ZtLocalStore store;

  @override
  Future<Map<String, Object?>?> read(String id) async {
    final item = await store.get(id);
    return item == null || item.deleted ? null : item.json;
  }

  @override
  Future<void> write(String id, Map<String, Object?> json) =>
      store.put(LocalItem(itemId: id, updatedAt: DateTime.now().toUtc(), json: json));

  @override
  Future<void> remove(String id) => store.put(LocalItem(itemId: id, updatedAt: DateTime.now().toUtc(), deleted: true));
}

/// One person's phone: their vault store, their shared spaces, the app's
/// providers.
class Phone {
  Phone(this.server, this.userId, this.seed);
  final InMemorySpaceServer server;
  final String userId;
  final int seed;
  late final ZtLocalStore vault;
  late final SharedSpaces spaces;
  late final ProviderContainer container;
  final Map<String, ZtLocalStore> spaceStores = {};

  Future<Phone> start() async {
    vault = await ZtLocalStore.open(appKey: key(seed));
    spaces = SharedSpaces(
      app: 'tasks',
      myUserId: userId,
      identity: await ZtIdentity.fromDek(key(seed + 100)),
      backend: server.backendFor(userId),
      privateStore: StorePrivate(vault),
      openStore: (id) async => spaceStores[id] ??= await ZtLocalStore.open(appKey: key(seed + 200)),
      deleteStore: (id) async => await spaceStores.remove(id)?.close(),
      deviceId: 'phone-$userId',
      policy: tasksSpacePolicy,
    );
    container = ProviderContainer(
      overrides: [
        tasksStoreProvider.overrideWithValue(vault),
        ztSharedSpacesProvider.overrideWith((ref) async => spaces),
        remindersEnabledProvider.overrideWithValue(false),
      ],
    );
    container.listen(sharedListsProvider, (_, _) {});
    await pump();
    return this;
  }

  SharedListsController get lists => container.read(sharedListsProvider.notifier);
  SharedListsState get state => container.read(sharedListsProvider);
  TaskManager get manager => container.read(taskManagerProvider);

  Future<void> sync() async {
    for (final l in state.lists) {
      await spaces.sync(await spaces.open(l.shared!.spaceId));
    }
    await lists.reload();
    await pump();
  }

  Future<void> dispose() async {
    container.dispose();
    await spaces.close();
  }
}

Future<void> pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Task task(String title, {String? listId}) => Task(
  id: title.toLowerCase(),
  title: title,
  listId: listId,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Shared-list writes for [TaskManager] tests.
class MemoryShared implements SharedTaskStore {
  final saved = <String, Task>{};
  final deleted = <String>[];
  @override
  Future<void> saveTask(Task t) async => saved[t.id] = t;
  @override
  Future<void> deleteTask(Task t) async => deleted.add('${t.spaceId}/${t.id}');
}

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  final deleted = <String>[];
  @override
  Future<void> save(Task t) async => saved[t.id] = t;
  @override
  Future<void> delete(String id) async => deleted.add(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Two people share a list', () {
    late InMemorySpaceServer server;
    late Phone a, b;

    setUp(() async {
      server = InMemorySpaceServer();
      a = await Phone(server, alice, 1).start();
      b = await Phone(server, bob, 2).start();
    });

    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    Future<String> shareWithBob() async {
      final spaceId = await a.lists.create(
        TaskList.create(name: 'Groceries', color: 0xFF43A047),
        myName: 'Alice',
        tasks: [
          task('Milk', listId: 'l1'),
          task('Bread', listId: 'l1'),
        ],
      );
      final link = await a.spaces.invite(spaceId);
      final started = await b.spaces.answer(SpaceInviteLink.parse(link.toString()), myName: 'Bob');
      await b.lists.reload();
      final waiting = b.state.lists.single;
      expect(waiting.shared!.waiting, isTrue, reason: 'Bob waits for Alice');
      final pending = await a.spaces.pendingJoins(spaceId);
      expect(pending.single.verificationCode, started.verificationCode);
      await a.spaces.confirm(pending.single);
      await b.sync();
      return spaceId;
    }

    test('the owner shares a list with its tasks; the other person sees it and its members', () async {
      final spaceId = await shareWithBob();
      final mine = a.state.lists.single;
      expect(mine.id, TaskList.sharedId(spaceId));
      expect(mine.name, 'Groceries');
      expect(mine.shared!.isAdmin, isTrue);
      expect(a.state.tasks.map((t) => t.title), unorderedEquals(['Milk', 'Bread']));
      expect(a.state.tasks.every((t) => t.listId == mine.id), isTrue);

      final theirs = b.state.lists.single;
      expect(theirs.shared!.waiting, isFalse);
      expect(theirs.name, 'Groceries');
      expect(theirs.color, 0xFF43A047);
      expect(theirs.shared!.isAdmin, isFalse);
      expect(theirs.shared!.members.map((m) => m.name), unorderedEquals(['Alice', 'Bob']));
      expect(b.state.tasks.map((t) => t.title), unorderedEquals(['Milk', 'Bread']));

      // The same lists and tasks reach the app's providers.
      expect(b.container.read(taskListProvider).lists.last.id, theirs.id);
      expect(b.manager.tasks.map((t) => t.title), containsAll(['Milk', 'Bread']));
      expect(b.manager.sharedReady, isTrue);
    });

    test('a member ticks a task off and adds one; the owner sees both', () async {
      await shareWithBob();
      final milk = b.manager.tasks.firstWhere((t) => t.title == 'Milk');
      await b.manager.toggleTaskComplete(milk.id);
      final eggs = Task.create(title: 'Eggs', listId: b.state.lists.single.id);
      await b.manager.addTask(eggs);
      await b.sync();
      await a.sync();
      expect(a.state.tasks.firstWhere((t) => t.title == 'Milk').isCompleted, isTrue);
      expect(a.state.tasks.map((t) => t.title), contains('Eggs'));
      // Stored without the device-side list id.
      final stored = await a.spaceStores.values.single.get(eggs.id);
      expect(stored!.json!.containsKey('listId'), isFalse);
    });

    test('only owners rename the list', () async {
      await shareWithBob();
      final theirs = b.state.lists.single;
      await expectLater(b.container.read(taskListProvider).save(theirs.copyWith(name: 'Mine now')), throwsStateError);
      await b.sync();
      await a.sync();
      expect(a.state.lists.single.name, 'Groceries');

      final mine = a.state.lists.single;
      await a.container.read(taskListProvider).save(mine.copyWith(name: 'Shopping'));
      await a.sync();
      await b.sync();
      expect(b.state.lists.single.name, 'Shopping');
    });

    test('a removed member loses the list and its tasks', () async {
      final spaceId = await shareWithBob();
      await a.spaces.remove(spaceId, bob);
      try {
        // The live update may have done it already.
        await b.spaces.sync(await b.spaces.open(spaceId));
      } on SpaceNotTrusted {
        // already wiped
      }
      await b.lists.reload();
      await pump();
      expect(b.state.lists, isEmpty);
      expect(b.manager.tasks, isEmpty);
    });

    test('leaving removes the list from this phone only', () async {
      final spaceId = await shareWithBob();
      await b.spaces.leave(spaceId);
      await b.lists.reload();
      expect(b.state.lists, isEmpty);
      await a.sync();
      expect(a.state.lists.single.shared!.members.length, 1);
      expect(a.state.tasks.length, 2);
    });
  });

  group('TaskManager with shared lists', () {
    test('saves and deletes go to the store each task lives in', () async {
      final own = MemoryWriter();
      final shared = MemoryShared();
      final manager = TaskManager(reminders: false)
        ..attach(source: () => Stream.value(<Task>[]), writer: own)
        ..setShared([task('Milk', listId: TaskList.sharedId('s1'))], writer: shared);
      await pump();
      await manager.addTask(task('Own'));
      await manager.toggleTaskComplete('milk');
      expect(own.saved.keys, ['own']);
      expect(shared.saved['milk']!.isCompleted, isTrue);

      await manager.permanentlyDeleteTask('milk');
      expect(shared.deleted, ['s1/milk']);
      expect(own.deleted, isEmpty);
    });

    test('moving a task into or out of a shared list moves it between stores', () async {
      final own = MemoryWriter();
      final shared = MemoryShared();
      final manager = TaskManager(reminders: false)
        ..attach(source: () => Stream.value([task('Own')]), writer: own)
        ..setShared([task('Milk', listId: TaskList.sharedId('s1'))], writer: shared);
      await pump();

      await manager.moveToList({'own'}, TaskList.sharedId('s1'));
      expect(shared.saved['own']!.listId, TaskList.sharedId('s1'));
      expect(own.deleted, ['own'], reason: 'the private copy goes');

      await manager.moveToList({'milk'}, null);
      expect(own.saved['milk']!.listId, isNull);
      expect(shared.deleted, ['s1/milk']);

      // Between two shared lists: saved in the new one, deleted from the old.
      await manager.moveToList({'own'}, TaskList.sharedId('s2'));
      expect(shared.saved['own']!.listId, TaskList.sharedId('s2'));
      expect(shared.deleted.last, 's1/own');
    });

    test('sharing a list drops only the private copies of its tasks', () async {
      final own = MemoryWriter();
      final manager = TaskManager(reminders: false)
        ..attach(source: () => Stream.value([task('Milk', listId: 'l1')]), writer: own)
        ..setShared([task('Milk', listId: TaskList.sharedId('s1'))], writer: MemoryShared());
      await pump();
      expect(manager.tasks.length, 2);
      await manager.dropPrivateCopies(['milk']);
      expect(own.deleted, ['milk']);
      expect(manager.tasks.single.listId, TaskList.sharedId('s1'));
    });

    test('taps on a task not read yet wait until shared lists are read', () async {
      final manager = TaskManager(reminders: false)
        ..attach(source: () => Stream.value(<Task>[]), writer: MemoryWriter())
        ..setShared(const [], ready: false);
      await pump();
      final done = <String>[];
      final tap = PendingTaskAction(type: PendingTaskActionType.complete, taskId: 'milk', at: DateTime(2026, 11, 11));
      await manager.applyPendingActions([tap], onDone: (a) async => done.add(a.taskId));
      expect(done, isEmpty, reason: 'kept in the queue');

      final shared = MemoryShared();
      manager.setShared([task('Milk', listId: TaskList.sharedId('s1'))], writer: shared);
      await manager.applyPendingActions([tap], onDone: (a) async => done.add(a.taskId));
      expect(done, ['milk']);
      expect(shared.saved['milk']!.isCompleted, isTrue);
    });
  });

  for (final lang in ['en', 'he']) {
    testWidgets('people screen ($lang): members, then invite, then leave, top to bottom', (tester) async {
      late Phone a;
      late String spaceId;
      await tester.runAsync(() async {
        final server = InMemorySpaceServer();
        a = await Phone(server, alice, 1).start();
        final b = await Phone(server, bob, 2).start();
        spaceId = await a.lists.create(TaskList.create(name: 'Groceries'), myName: 'Alice');
        final link = await a.spaces.invite(spaceId);
        await b.spaces.answer(SpaceInviteLink.parse(link.toString()), myName: 'Bob');
        await a.spaces.confirm((await a.spaces.pendingJoins(spaceId)).single);
        await a.sync();
        await b.dispose();
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: a.container,
        child: MaterialApp(
          locale: Locale(lang),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          home: SharedListPage(spaceId: spaceId),
        ),
      ));
      await tester.runAsync(() => pump());
      await tester.pump();
      final l = lookupAppL10n(Locale(lang));
      expect(find.text('Groceries'), findsOneWidget);
      final aliceRow = find.text(l.youName('Alice'));
      final bobRow = find.text('Bob');
      final invite = find.text(l.invitePeople);
      final leave = find.text(l.leaveList);
      for (final f in [aliceRow, bobRow, invite, leave]) {
        expect(f, findsOneWidget);
      }
      final ys = [for (final f in [aliceRow, bobRow, invite, leave]) tester.getCenter(f).dy];
      expect(ys, orderedEquals([...ys]..sort()), reason: 'stacked in this order');
      // Nothing overlaps: each row starts below the one before.
      expect(tester.getTopLeft(bobRow).dy, greaterThanOrEqualTo(tester.getBottomLeft(aliceRow).dy));
      // The invite button is fully on screen and tappable.
      final button = tester.getRect(find.ancestor(of: invite, matching: find.byType(FilledButton)));
      expect(button.width, greaterThan(100));
      expect(button.height, greaterThanOrEqualTo(40));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => a.dispose());
    });
  }
}
