import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// The account's task lists, synced and encrypted like tasks (see
/// `taskListsCollection`). The default list is always first, even before
/// it has been stored.
class TaskListProvider extends ChangeNotifier {
  List<TaskList> _stored = [];
  StreamSubscription<List<TaskList>>? _subscription;
  Future<void> Function(TaskList)? _save;
  Future<void> Function(String)? _delete;
  bool _disposed = false;

  /// Every list, default first, then by position and name.
  List<TaskList> get lists {
    final defaultList = _stored.where((l) => l.isDefault).firstOrNull ?? TaskList.fallbackDefault;
    final others = _stored.where((l) => !l.isDefault).toList()
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return List.unmodifiable([defaultList, ...others]);
  }

  /// The list with [id]; tasks with a missing or unknown list are in the
  /// default one.
  TaskList byId(String? id) {
    final all = lists;
    return all.where((l) => l.id == (id ?? TaskList.defaultId)).firstOrNull ?? all.first;
  }

  /// Whether a task with [listId] belongs to [list] (unknown ids count as
  /// the default list, so nothing is ever hidden).
  bool contains(TaskList list, String? listId) => byId(listId).id == list.id;

  void attach({
    Stream<List<TaskList>>? source,
    Future<void> Function(TaskList)? save,
    Future<void> Function(String)? delete,
  }) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _save = save;
    _delete = delete;
    _stored = [];
    _notify();
    _subscription = source?.listen((lists) {
      _stored = lists;
      _notify();
    }, onError: (Object _) {});
  }

  Future<void> Function(TaskList) get _requireSave =>
      _save ?? (throw StateError('Your tasks are locked. Unlock to make changes.'));

  Future<TaskList> create(String name, {int? color}) async {
    final last = lists.last.position;
    final list = TaskList.create(name: name.trim(), color: color, position: last + 1);
    await save(list);
    return list;
  }

  /// Adds or updates [list] (also how the default list is renamed).
  Future<void> save(TaskList list) async {
    final save = _requireSave;
    _stored = [..._stored.where((l) => l.id != list.id), list];
    _notify();
    await save(list);
  }

  /// Removes the list itself. Its tasks are handled by the caller.
  Future<void> remove(String id) async {
    if (id == TaskList.defaultId) throw StateError('The default list can\'t be deleted.');
    final delete = _delete ?? (throw StateError('Your tasks are locked.'));
    _stored = _stored.where((l) => l.id != id).toList();
    _notify();
    await delete(id);
  }

  void _notify() {
    if (_disposed) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => _notify());
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
