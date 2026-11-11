import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

/// Shared lists (T12): a list shared with other Zero-Trust users lives in
/// its own shared space (core Z24). The space holds the list's name and
/// colour (item [listItemId], kind `task_list`) and its tasks (items with
/// no kind, exactly like the account's own tasks). Everything in it is end
/// to end encrypted with the space's key, which only members hold; the
/// server sees member ids and encrypted blobs, never names or tasks.
///
/// Only owners (space admins) may change the list's name and colour; every
/// member adds, edits, ticks and deletes tasks.
const SpacePolicy tasksSpacePolicy = SpacePolicy(adminOnlyKinds: {'task_list'});

/// The item that names the list inside its space.
const String listItemId = 'list';

/// Where Tasks 0.4.0 kept the name other members see. It now lives in
/// Core's shared item (zt_sharing_ui's [ZtSharingName]); an old one is moved
/// there once.
const String legacySharingNameItemId = 'tasks.sharing_name';

/// Tasks of all shared lists and the lists themselves, read from this
/// phone's copy of each space (so they show offline too).
class SharedListsState {
  const SharedListsState({this.lists = const [], this.tasks = const [], this.ready = false, this.available = false});

  final List<TaskList> lists;
  final List<Task> tasks;

  /// Read at least once since the vault opened.
  final bool ready;

  /// Sharing can be used now (vault open, sharing set up). False in tests
  /// and when the core couldn't start sharing.
  final bool available;
}

class SharedListsController extends Notifier<SharedListsState> implements SharedTaskStore {
  ZtLocalStore? _private;
  SharedSpaces? _spaces;
  final Map<String, StreamSubscription<Set<String>>> _watching = {};
  StreamSubscription<Set<String>>? _anchors;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  @override
  SharedListsState build() {
    _disposed = false;
    final store = ref.watch(tasksStoreProvider);
    final spacesValue = ref.watch(ztSharedSpacesProvider);
    _private = store;
    _spaces = switch (spacesValue) {
      AsyncData(:final value) => value,
      _ => null,
    };
    ref.onDispose(() {
      _disposed = true;
      _anchors?.cancel();
      for (final s in _watching.values) {
        s.cancel();
      }
      _watching.clear();
    });
    if (store == null) return const SharedListsState();
    if (_spaces == null) {
      // Still opening: wait. Failed (no sharing backend): nothing shared.
      return SharedListsState(ready: spacesValue.hasError);
    }
    // Keep the spaces syncing while the vault is open, and read again
    // whenever a sync or a membership change lands.
    ref.listen(ztSpacesProvider, (_, _) => reload());
    _anchors = store.changes.listen((ids) {
      if (ids.any((id) => id.startsWith('zt.space-anchor/'))) reload();
    });
    scheduleMicrotask(reload);
    scheduleMicrotask(_moveLegacySharingName);
    return const SharedListsState(available: true);
  }

  SpacesController get _controller => ref.read(ztSpacesProvider.notifier);

  /// Reads every shared list again from this phone's copies. Completes
  /// once a read that started after this call has finished.
  Future<void> reload() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = () async {
      try {
        do {
          _again = false;
          await _reload();
        } while (_again && !_disposed);
      } finally {
        _running = null;
      }
    }();
  }

  Future<void> _reload() async {
    final store = _private;
    final spaces = _spaces;
    if (store == null || spaces == null || _disposed) return;
    final spaceIds = <String>{
      for (final item in await store.all())
        if (!item.deleted && item.itemId.startsWith('zt.space-anchor/'))
          item.itemId.substring('zt.space-anchor/'.length),
    };
    final entries = ref.read(ztSpacesProvider);
    final lists = <TaskList>[];
    final tasks = <Task>[];
    for (final spaceId in spaceIds) {
      final SharedSpace space;
      try {
        space = await spaces.open(spaceId);
      } on Object {
        continue;
      }
      if (space.gone) continue;
      _watch(space);
      final entry = entries[spaceId];
      TaskList? meta;
      final listId = TaskList.sharedId(spaceId);
      for (final item in await space.store.all()) {
        if (item.deleted) continue;
        if (item.itemId == listItemId) {
          meta = taskListsCollection.decode(item);
          continue;
        }
        final task = tasksCollection.decode(item);
        if (task != null) tasks.add(task.copyWith(listId: listId));
      }
      final info = SharedListInfo(
        spaceId: spaceId,
        isAdmin: space.isAdmin,
        members: space.members,
        joinCode: entry?.joinCode,
        waiting: meta == null,
        myUserId: spaces.myUserId,
      );
      lists.add(
        (meta ??
                TaskList(
                  id: listId,
                  name: '',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                ))
            .withShared(info),
      );
    }
    for (final gone in _watching.keys.where((id) => !spaceIds.contains(id)).toList()) {
      await _watching.remove(gone)?.cancel();
    }
    if (_disposed) return;
    state = SharedListsState(lists: lists, tasks: tasks, ready: true, available: true);
  }

  void _watch(SharedSpace space) {
    if (_watching.containsKey(space.id)) return;
    final store = space.store;
    if (store is ZtLocalStore) {
      _watching[space.id] = store.changes.listen((_) => reload());
    }
  }

  SpacesController _require() {
    if (!state.available) throw StateError('Sharing isn\'t available right now.');
    return _controller;
  }

  /// Saves a task of a shared list in its space.
  @override
  Future<void> saveTask(Task task) async {
    final spaceId = task.spaceId;
    if (spaceId == null) throw ArgumentError('Not a shared task');
    final space = await _spaces!.open(spaceId);
    final previous = (await space.store.get(task.id))?.json;
    final stored = task.copyWith(clearListId: true);
    await _require().save(
      spaceId,
      task.id,
      tasksCollection.encode(stored, previous: previous != null && tasksCollection.owns(previous) ? previous : null),
    );
    await reload();
  }

  @override
  Future<void> deleteTask(Task task) async {
    final spaceId = task.spaceId;
    if (spaceId == null) return;
    await _require().delete(spaceId, task.id);
    await reload();
  }

  /// Renames or recolours a shared list (owners only).
  Future<void> saveList(TaskList list) async {
    final spaceId = list.shared?.spaceId;
    if (spaceId == null) throw ArgumentError('Not a shared list');
    if (!(await _spaces!.open(spaceId)).isAdmin) {
      throw StateError('Only the list\'s owners can rename it.');
    }
    final stored = TaskList(
      id: listItemId,
      name: list.name,
      color: list.color,
      position: list.position,
      extra: list.extra,
      createdAt: list.createdAt,
      updatedAt: DateTime.now(),
    );
    await _require().save(spaceId, listItemId, taskListsCollection.encode(stored));
    await reload();
  }

  /// Makes a new shared list with this account as its owner. [tasks] (the
  /// list's tasks so far, when an existing list is being shared) are
  /// copied in; the caller removes the originals.
  Future<String> create(TaskList list, {required String myName, List<Task> tasks = const []}) async {
    final controller = _require();
    final space = await controller.create(myName: myName);
    final sharedList = list.withShared(SharedListInfo(spaceId: space.id, isAdmin: true));
    await saveList(sharedList);
    for (final t in tasks) {
      await controller.save(space.id, t.id, tasksCollection.encode(t.copyWith(clearListId: true)));
    }
    await reload();
    return space.id;
  }

  Future<void> leave(String spaceId) async {
    await _require().leave(spaceId);
    await reload();
  }

  Future<void> deleteForEveryone(String spaceId) async {
    await _require().deleteSpace(spaceId);
    await reload();
  }

  /// Moves the name saved by Tasks 0.4.0 to Core's shared item, unless
  /// that one is already set.
  Future<void> _moveLegacySharingName() async {
    final store = _private;
    if (store == null || _disposed) return;
    try {
      final old = await store.get(legacySharingNameItemId);
      if (old == null || old.deleted) return;
      final name = (old.json?['name'] as String?) ?? '';
      final names = ref.read(ztSharingNameProvider);
      if (name.isNotEmpty && (await names.read()).isEmpty) await names.save(name);
      await ref.read(ztSyncControllerProvider.notifier).delete(legacySharingNameItemId);
    } on Object {
      // Tried again on the next unlock.
    }
  }
}

final sharedListsProvider = NotifierProvider<SharedListsController, SharedListsState>(SharedListsController.new);
