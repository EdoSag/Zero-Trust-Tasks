import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/services/recurrence_service.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/models/backup_preview.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Saves and deletes go through the core's sync, so every edit is encrypted,
/// stored on the device and pushed to the account's other devices.
abstract interface class TaskWriter {
  Future<void> save(Task task);
  Future<void> delete(String taskId);
}

/// The vault's tasks while it is unlocked, read from the core's encrypted
/// local store and kept current as this or another device changes them.
///
/// The UI reads [tasks] and calls the mutations; each one updates the list
/// at once and then writes through [TaskWriter].
class TaskManager extends ChangeNotifier {
  TaskManager({this.reminders = true});

  /// Whether to schedule notifications (off in tests).
  final bool reminders;

  /// Tasks in the account's own vault, and tasks of lists shared with
  /// other people (each list in its own shared space).
  List<Task> _private = [];
  List<Task> _shared = [];
  SharedTaskStore? _sharedWriter;
  bool _sharedReady = false;

  List<Task> get _tasks => [..._private, ..._shared];
  set _tasks(List<Task> all) {
    _private = [for (final t in all) if (!t.isShared) t];
    _shared = [for (final t in all) if (t.isShared) t];
  }

  bool _isLoading = true;
  String? _error;
  Task? _lastDeletedTask;
  TaskWriter? _writer;
  Stream<List<Task>> Function()? _source;
  StreamSubscription<List<Task>>? _subscription;
  bool _remindersScheduled = false;
  bool _disposed = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;

  /// Whether shared lists have been read since the vault opened (from this
  /// phone's copy, so also offline). Taps queued while locked wait for it,
  /// so a tick on a shared task isn't dropped as "unknown task".
  bool get sharedReady => _sharedReady;

  /// The shared lists' tasks as they are now, and where to save them.
  /// Reminders follow tasks that arrive from other members.
  void setShared(List<Task> tasks, {SharedTaskStore? writer, bool ready = true}) {
    final before = {for (final t in _shared) t.id: t};
    _shared = tasks;
    _sharedWriter = writer;
    final wasReady = _sharedReady;
    _sharedReady = ready;
    _notify();
    if (!reminders) return;
    final now = {for (final t in tasks) t.id: t};
    for (final t in tasks) {
      final old = before[t.id];
      final due = t.deletedAt == null && !t.isCompleted;
      if (old == null || !wasReady) {
        if (due) _remind(t);
      } else if (old.reminderAt != t.reminderAt ||
          old.isCompleted != t.isCompleted ||
          old.deletedAt != t.deletedAt ||
          old.title != t.title) {
        due ? _remind(t) : _cancelReminder(t.id);
      }
    }
    for (final id in before.keys) {
      if (!now.containsKey(id)) _cancelReminder(id);
    }
  }
  String? get error => _error;

  /// Connects to an open store, or (with nulls) disconnects when the vault
  /// locks and forgets every task in memory.
  void attach({Stream<List<Task>> Function()? source, TaskWriter? writer}) {
    _source = source;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _writer = writer;
    _lastDeletedTask = null;
    _remindersScheduled = false;
    if (source == null) {
      _private = [];
      _shared = [];
      _sharedWriter = null;
      _sharedReady = false;
      _isLoading = true;
      _error = null;
      _notify();
      return;
    }
    _listen(source);
  }

  /// Reads the tasks again after a read error.
  Future<void> loadTasks() async {
    final source = _source;
    if (source == null) return;
    unawaited(_subscription?.cancel());
    _isLoading = true;
    _error = null;
    _notify();
    _listen(source);
  }

  void _listen(Stream<List<Task>> Function() source) {
    _subscription = source().listen(
      (tasks) {
        _private = tasks;
        _isLoading = false;
        _error = null;
        _notify();
        _afterFirstLoad();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = currentL10n.cantReadTasks(ztErrorMessage(e));
        _notify();
      },
    );
  }

  /// Once per unlock: empties trash older than 30 days and puts reminders
  /// back for tasks that arrived from other devices.
  void _afterFirstLoad() {
    if (_remindersScheduled) return;
    _remindersScheduled = true;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final t in List.of(_tasks)) {
      if (t.deletedAt != null && t.deletedAt!.isBefore(cutoff)) {
        unawaited(permanentlyDeleteTask(t.id));
      } else if (reminders && t.deletedAt == null && !t.isCompleted) {
        unawaited(NotificationService.instance.scheduleTaskReminder(t));
      }
    }
  }

  void _notify() {
    if (_disposed) return;
    // A lock can arrive while widgets are building (a covered screen wakes
    // up as the routes above it are popped). The data is already cleared;
    // listeners hear about it once the frame is done.
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

  /// Tasks that aren't in the trash or the archive: what the dashboard
  /// counts and shows.
  Iterable<Task> get _active => _tasks.where((t) => t.deletedAt == null && !t.isArchived);

  List<Task> get activeTasks => _active.toList();

  /// The [count] most recently changed active tasks, newest first.
  List<Task> recentTasks([int count = 5]) =>
      (_active.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(count).toList();

  int get totalTasks => _active.length;
  int get completedTasksCount => _active.where((t) => t.isCompleted).length;
  /// Every completed task still stored, archived ones included: the
  /// history Insights shows next to its completion chart.
  int get completedEverCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingTasksCount => _active.where((t) => !t.isCompleted).length;
  int get overdueTasksCount => _active.where((t) => t.isOverdue).length;

  Map<TaskPriority, int> get tasksByPriorityCount => {
        for (final p in [
          TaskPriority.critical,
          TaskPriority.high,
          TaskPriority.medium,
          TaskPriority.low,
        ])
          p: _active.where((t) => t.priority == p).length,
      };

  TaskWriter get _requireWriter =>
      _writer ?? (throw StateError('Your tasks are locked. Unlock to make changes.'));

  _Store _writerFor(Task task) {
    if (!task.isShared) {
      final w = _requireWriter;
      return _Store(w.save, (t) => w.delete(t.id));
    }
    final w = _sharedWriter ?? (throw StateError('Shared lists aren\'t open yet. Try again in a moment.'));
    return _Store(w.saveTask, w.deleteTask);
  }

  /// Shows [changed] at once, then saves them.
  Future<void> _put(List<Task> changed) async {
    final writers = [for (final task in changed) _writerFor(task)];
    var tasks = _tasks;
    for (final task in changed) {
      final i = tasks.indexWhere((t) => t.id == task.id);
      if (i == -1) {
        tasks = [...tasks, task];
      } else {
        tasks = List.of(tasks)..[i] = task;
      }
    }
    _tasks = tasks;
    _notify();
    try {
      for (var i = 0; i < changed.length; i++) {
        await writers[i].save(changed[i]);
      }
    } on Object {
      // The list shows the edit already; the next read puts it back as stored.
      await loadTasks();
      rethrow;
    }
  }

  Task? _find(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _remind(Task task) {
    if (reminders) unawaited(NotificationService.instance.scheduleTaskReminder(task));
  }

  void _cancelReminder(String id) {
    if (reminders) unawaited(NotificationService.instance.cancelReminder(id));
  }

  Future<void> addTask(Task task) async {
    await _put([task]);
    _remind(task);
  }

  Future<void> updateTask(Task updatedTask) async {
    final old = _find(updatedTask.id);
    if (old == null) return;
    final saved = updatedTask.copyWith(updatedAt: DateTime.now());
    // The editor moved it to a list in another store (own <-> shared, or
    // another shared list): the old copy goes, like with "Move to list".
    final from = TaskList.spaceIdOf(old.listId) != TaskList.spaceIdOf(saved.listId) ? _writerFor(old) : null;
    await _put([saved]);
    await from?.delete(old);
    _remind(saved);
  }

  /// Soft-deletes a task (moves it to trash). [undoDelete] restores it.
  Future<void> deleteTask(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    _lastDeletedTask = task;
    await _put([task.copyWith(deletedAt: DateTime.now(), updatedAt: DateTime.now())]);
    _cancelReminder(taskId);
  }

  Future<void> undoDelete() async {
    final task = _lastDeletedTask;
    if (task == null) return;
    _lastDeletedTask = null;
    await restoreFromTrash(task.id);
  }

  Future<void> restoreFromTrash(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    final restored = task.copyWith(clearDeletedAt: true, updatedAt: DateTime.now());
    await _put([restored]);
    _remind(restored);
  }

  /// Deletes for good, on every device.
  Future<void> permanentlyDeleteTask(String taskId) async {
    final task = _find(taskId);
    if (task == null) {
      await _requireWriter.delete(taskId);
      return;
    }
    final writer = _writerFor(task);
    _tasks = _tasks.where((t) => t.id != taskId).toList();
    _notify();
    _cancelReminder(taskId);
    await writer.delete(task);
  }

  /// Deletes the account's own copies of [taskIds] after they were copied
  /// into a shared list (same ids), leaving the shared copies and their
  /// reminders alone.
  Future<void> dropPrivateCopies(Iterable<String> taskIds) async {
    final writer = _requireWriter;
    final ids = taskIds.toSet();
    _private = _private.where((t) => !ids.contains(t.id)).toList();
    _notify();
    for (final id in ids) {
      await writer.delete(id);
    }
  }

  Future<void> archiveTask(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    await _put([task.copyWith(isArchived: true, updatedAt: DateTime.now())]);
  }

  Future<void> unarchiveTask(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    await _put([task.copyWith(isArchived: false, updatedAt: DateTime.now())]);
  }

  List<Task> getTrashedTasks() => _tasks.where((t) => t.deletedAt != null).toList()
    ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  /// A copy of [taskId] with a new id, open again, "(Copy)" in the title.
  Future<void> duplicateTask(String taskId) async {
    final original = _find(taskId);
    if (original == null) return;
    final now = DateTime.now();
    await _put([
      Task(
        id: const Uuid().v4(),
        title: currentL10n.copyOf(original.title),
        description: original.description,
        category: original.category,
        priority: original.priority,
        startDate: original.startDate,
        dueDate: original.dueDate,
        reminderAt: null,
        recurrence: original.recurrence,
        tags: List.of(original.tags),
        notes: original.notes,
        links: List.of(original.links),
        isCompleted: false,
        isArchived: false,
        subTasks: original.subTasks.map((s) => s.copyWith(isCompleted: false)).toList(),
        listId: original.listId,
        starred: original.starred,
        noteIds: List.of(original.noteIds),
        contactIds: List.of(original.contactIds),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  List<Task> getArchivedTasks() =>
      _tasks.where((t) => t.isArchived && t.deletedAt == null).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> toggleTaskComplete(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;

    // A recurring task rolls forward instead, unless its recurrence ended.
    if (!task.isCompleted && task.recurrence != null) {
      final next = RecurrenceService.nextOccurrence(task);
      if (next != null && !RecurrenceService.hasEnded(task.recurrence!, next)) {
        final rolled = task.copyWith(
          dueDate: next,
          clearReminderAt: true,
          subTasks: task.subTasks.map((s) => s.copyWith(isCompleted: false)).toList(),
          updatedAt: DateTime.now(),
        );
        await _put([rolled]);
        _remind(rolled);
        return;
      }
    }

    final completing = !task.isCompleted;
    await _put([
      task.copyWith(
        isCompleted: completing,
        completedAt: completing ? DateTime.now() : null,
        clearCompletedAt: !completing,
        updatedAt: DateTime.now(),
      ),
    ]);
    if (completing) _cancelReminder(taskId);
  }

  Future<void> toggleSubTaskComplete(String taskId, String subTaskId) async {
    final task = _find(taskId);
    if (task == null) return;
    await _put([
      task.copyWith(
        subTasks: [
          for (final st in task.subTasks)
            st.id == subTaskId ? st.copyWith(isCompleted: !st.isCompleted) : st,
        ],
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  List<Task> getTasksByCategory(String? category) =>
      category == null ? activeTasks : _active.where((t) => t.category == category).toList();

  List<Task> getTasksByPriority(TaskPriority priority) =>
      _active.where((t) => t.priority == priority).toList();

  List<Task> getOverdueTasks() => _active.where((t) => t.isOverdue).toList();
  List<Task> getCompletedTasks() => _active.where((t) => t.isCompleted).toList();
  List<Task> getPendingTasks() => _active.where((t) => !t.isCompleted).toList();

  List<String?> getCategories() {
    final categories =
        _active.where((t) => t.category != null).map((t) => t.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// What importing [incoming] would change, without changing anything.
  BackupPreview previewImport(List<Task> incoming) {
    final local = {for (final t in _tasks) t.id: t};
    var toAdd = 0;
    var toUpdate = 0;
    for (final t in incoming) {
      final existing = local[t.id];
      if (existing == null) {
        toAdd++;
      } else if (t.updatedAt.isAfter(existing.updatedAt)) {
        toUpdate++;
      }
    }
    return BackupPreview(
      backupTaskCount: incoming.length,
      toAdd: toAdd,
      toUpdate: toUpdate,
      toRemove: 0,
    );
  }

  /// Adds [incoming] tasks; existing ones are replaced only by a newer copy.
  /// Nothing local is removed. Returns how many were written.
  Future<int> importTasks(List<Task> incoming) async {
    final local = {for (final t in _tasks) t.id: t};
    final changed = [
      for (final t in incoming)
        if (local[t.id] == null || t.updatedAt.isAfter(local[t.id]!.updatedAt)) t,
    ];
    if (changed.isNotEmpty) await _put(changed);
    for (final t in changed) {
      if (t.deletedAt == null && !t.isCompleted) _remind(t);
    }
    return changed.length;
  }

  Future<void> bulkComplete(Set<String> taskIds, {required bool complete}) async {
    final now = DateTime.now();
    await _put([
      for (final id in taskIds)
        if (_find(id) case final t?)
          t.copyWith(
            isCompleted: complete,
            completedAt: complete ? now : null,
            clearCompletedAt: !complete,
            updatedAt: now,
          ),
    ]);
  }

  Future<void> bulkDelete(Set<String> taskIds) async {
    final now = DateTime.now();
    await _put([
      for (final id in taskIds)
        if (_find(id) case final t?) t.copyWith(deletedAt: now, updatedAt: now),
    ]);
    for (final id in taskIds) {
      _cancelReminder(id);
    }
  }

  Future<void> bulkSetCategory(Set<String> taskIds, String? category) async {
    final now = DateTime.now();
    await _put([
      for (final id in taskIds)
        if (_find(id) case final t?)
          Task.fromJson({...t.toJson(), 'category': category, 'updatedAt': now.toIso8601String()}),
    ]);
  }

  Future<void> bulkSetPriority(Set<String> taskIds, TaskPriority priority) async {
    final now = DateTime.now();
    await _put([
      for (final id in taskIds)
        if (_find(id) case final t?) t.copyWith(priority: priority, updatedAt: now),
    ]);
  }

  Future<void> toggleStar(String taskId) async {
    final task = _find(taskId);
    if (task == null) return;
    await _put([task.copyWith(starred: !task.starred, updatedAt: DateTime.now())]);
  }

  /// Moves tasks to the list [listId] (null or [TaskList.defaultId]: the
  /// default list). They go to the bottom of that list's "My order".
  ///
  /// Moving between the account's own lists and a shared list (or between
  /// two shared lists) moves the task to the other store: it is saved
  /// there first, then deleted where it was.
  Future<void> moveToList(Set<String> taskIds, String? listId) async {
    final target = listId == TaskList.defaultId ? null : listId;
    final now = DateTime.now();
    final moved = <Task>[];
    final leaving = <Task>[];
    for (final id in taskIds) {
      final t = _find(id);
      if (t == null || t.listId == target) continue;
      moved.add(t.copyWith(listId: target, clearListId: target == null, clearPosition: true, updatedAt: now));
      if (TaskList.spaceIdOf(t.listId) != TaskList.spaceIdOf(target)) leaving.add(t);
    }
    if (moved.isEmpty) return;
    final oldWriters = {for (final t in leaving) t.id: _writerFor(t)};
    await _put(moved);
    for (final t in leaving) {
      await oldWriters[t.id]!.delete(t);
    }
    for (final t in moved) {
      if (oldWriters.containsKey(t.id) && t.deletedAt == null && !t.isCompleted) _remind(t);
    }
  }

  /// Puts the task at [oldIndex] of [ordered] (one list in "My order") at
  /// [newIndex], counted after it is removed. Tasks that have never been
  /// dragged get positions too, so the whole list keeps its order.
  Future<void> reorder(List<Task> ordered, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= ordered.length) return;
    final list = List.of(ordered);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    final now = DateTime.now();
    final changed = <Task>[];
    for (var i = 0; i < list.length; i++) {
      final position = (i + 1) * 1024.0;
      if (list[i].position != position) {
        changed.add(list[i].copyWith(position: position, updatedAt: now));
      }
    }
    if (changed.isNotEmpty) await _put(changed);
  }

  /// Turns [taskId] into a subtask at the end of [parentId] (Google Tasks'
  /// "indent"). The task itself goes to trash, so it can be restored.
  Future<void> makeSubtaskOf(String taskId, String parentId) async {
    final task = _find(taskId);
    final parent = _find(parentId);
    if (task == null || parent == null || taskId == parentId) return;
    final now = DateTime.now();
    await _put([
      parent.copyWith(
        subTasks: [
          ...parent.subTasks,
          SubTask(id: const Uuid().v4(), title: task.title, isCompleted: task.isCompleted),
          // A task's own subtasks come along, one level up.
          ...task.subTasks.map((s) => s.copyWith(id: const Uuid().v4())),
        ],
        updatedAt: now,
      ),
      task.copyWith(deletedAt: now, updatedAt: now),
    ]);
    _cancelReminder(taskId);
  }

  /// Turns a subtask into a task of its own in the same list, just below
  /// its parent ("outdent").
  Future<Task?> promoteSubTask(String taskId, String subTaskId) async {
    final parent = _find(taskId);
    if (parent == null) return null;
    final sub = parent.subTasks.where((s) => s.id == subTaskId).firstOrNull;
    if (sub == null) return null;
    final now = DateTime.now();
    final promoted = Task.create(title: sub.title, listId: parent.listId).copyWith(
      isCompleted: sub.isCompleted,
      completedAt: sub.isCompleted ? now : null,
      position: parent.position == null ? null : parent.position! + 0.5,
    );
    await _put([
      parent.copyWith(subTasks: parent.subTasks.where((s) => s.id != subTaskId).toList(), updatedAt: now),
      promoted,
    ]);
    return promoted;
  }

  /// Moves every task of list [listId] to trash (when the list is deleted).
  Future<int> trashList(String listId) async {
    final now = DateTime.now();
    final inList = _tasks
        .where((t) => t.deletedAt == null && (t.listId ?? TaskList.defaultId) == listId)
        .toList();
    if (inList.isEmpty) return 0;
    await _put([for (final t in inList) t.copyWith(deletedAt: now, updatedAt: now)]);
    for (final t in inList) {
      _cancelReminder(t.id);
    }
    return inList.length;
  }

  /// Applies taps made while the vault was locked: Complete and Snooze on a
  /// reminder, ticks on the home-screen widget. Unknown or already-done
  /// tasks are skipped. Returns how many tasks changed.
  ///
  /// [onDone] runs after each action is saved (or skipped), before the next
  /// one, so the caller can drop it from its queue at once. A failure part
  /// way then never replays an action that already took effect, which for
  /// a repeating task would skip another occurrence.
  Future<int> applyPendingActions(
    List<PendingTaskAction> actions, {
    Future<void> Function(PendingTaskAction action)? onDone,
  }) async {
    var changed = 0;
    for (final action in actions) {
      // Maybe a shared list's task that hasn't been read yet: kept queued.
      if (!_sharedReady && _find(action.taskId) == null) continue;
      if (await _applyPending(action)) changed++;
      await onDone?.call(action);
    }
    return changed;
  }

  Future<bool> _applyPending(PendingTaskAction action) async {
    final task = _find(action.taskId);
    if (task == null || task.deletedAt != null) return false;
    switch (action.type) {
      case PendingTaskActionType.complete:
        if (task.isCompleted) return false;
        await toggleTaskComplete(task.id);
      case PendingTaskActionType.snooze:
        final until = action.until;
        if (until == null || task.isCompleted) return false;
        // The notification for the new time is already scheduled.
        await _put([task.copyWith(reminderAt: until, updatedAt: DateTime.now())]);
    }
    return true;
  }

  /// Tasks of one list in "My order", open ones only (what the widget and
  /// a dragged list show).
  List<Task> openTasksInOrder({String? listId}) => _tasks
      .where((t) =>
          t.deletedAt == null &&
          !t.isArchived &&
          !t.isCompleted &&
          (listId == null || (t.listId ?? TaskList.defaultId) == listId))
      .toList()
    ..sort(TaskFilterService.compareManual);

  /// (date, completions) for the last [days] days, oldest first.
  List<MapEntry<DateTime, int>> getCompletionTrend(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - (days - 1 - i));
      final count = _tasks.where((t) {
        final c = t.completedAt;
        return c != null && c.year == day.year && c.month == day.month && c.day == day.day;
      }).length;
      return MapEntry(day, count);
    });
  }

  /// Priority breakdown of active (not trashed, not archived) tasks.
  Map<TaskPriority, int> get activePriorityBreakdown {
    final active = _tasks.where((t) => t.deletedAt == null && !t.isArchived);
    return {for (final p in TaskPriority.values) p: active.where((t) => t.priority == p).length};
  }
}

/// Where shared-list tasks are saved (see `SharedListsController`).
abstract interface class SharedTaskStore {
  Future<void> saveTask(Task task);

  /// [task] as it was stored: its list id names the space it was in.
  Future<void> deleteTask(Task task);
}

class _Store {
  const _Store(this.save, this.delete);
  final Future<void> Function(Task) save;
  final Future<void> Function(Task) delete;
}

/// Shared-list tasks know their list by its id; see [TaskList.sharedId].
extension SharedTask on Task {
  bool get isShared => TaskList.spaceIdOf(listId) != null;
  String? get spaceId => TaskList.spaceIdOf(listId);
}

/// [TaskWriter] over the core: [tasksCollection] in the account's store.
class CoreTaskWriter implements TaskWriter {
  CoreTaskWriter({required this.store, required this.sync});

  final LocalItemStore store;

  /// Waits for the sync engine, which opens just after the store.
  final Future<SyncController> Function() sync;

  @override
  Future<void> save(Task task) async => tasksCollection.save(await sync(), store, task);

  @override
  Future<void> delete(String taskId) async => tasksCollection.delete(await sync(), taskId);
}
