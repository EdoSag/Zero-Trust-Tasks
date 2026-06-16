import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/services/recurrence_service.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/models/sync_result.dart';
import 'package:zero_trust_tasks/models/backup_preview.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

@NowaGenerated()
class TaskManager extends ChangeNotifier {
  TaskManager();

  factory TaskManager.of(BuildContext context, {bool listen = false}) {
    return Provider.of<TaskManager>(context, listen: listen);
  }

  List<Task> _tasks = [];

  bool _isLoading = false;

  String? _error;

  Task? _lastDeletedTask;

  List<Task> get tasks {
    return List.unmodifiable(_tasks);
  }

  bool get isLoading {
    return _isLoading;
  }

  String? get error {
    return _error;
  }

  int get totalTasks {
    return _tasks.length;
  }

  int get completedTasksCount {
    return _tasks.where((t) => t.isCompleted).length;
  }

  int get pendingTasksCount {
    return _tasks.where((t) => !t.isCompleted).length;
  }

  int get overdueTasksCount {
    return _tasks.where((t) => t.isOverdue).length;
  }

  Map<TaskPriority, int> get tasksByPriorityCount {
    return {
      TaskPriority.critical:
          _tasks.where((t) => t.priority == TaskPriority.critical).length,
      TaskPriority.high:
          _tasks.where((t) => t.priority == TaskPriority.high).length,
      TaskPriority.medium:
          _tasks.where((t) => t.priority == TaskPriority.medium).length,
      TaskPriority.low:
          _tasks.where((t) => t.priority == TaskPriority.low).length,
    };
  }

  Future<void> loadTasks() async {
    if (!EncryptionService.isUnlocked) {
      _error = 'Session locked. Please unlock first.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString('encrypted_tasks');
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = await EncryptionService.decryptData(
          encryptedData,
        );
        final List<dynamic> tasksJson =
            jsonDecode(decryptedJson) as List<dynamic>;
        _tasks = tasksJson
            .map((json) => Task.fromJson(json as Map<String, dynamic>))
            .toList();
        // Auto-purge tasks that have been in the trash for more than 30 days.
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        _tasks.removeWhere(
          (t) => t.deletedAt != null && t.deletedAt!.isBefore(cutoff),
        );
      } else {
        _tasks = [];
      }
    } on Exception {
      _error = 'Invalid password or corrupted data';
      _tasks = [];
    } catch (e) {
      _error = 'Failed to load tasks: ${e.toString()}';
      _tasks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTasks() async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot save tasks.');
    }
    try {
      final tasksJson = _tasks.map((task) => task.toJson()).toList();
      final jsonString = jsonEncode(tasksJson);
      final encryptedData = await EncryptionService.encryptData(jsonString);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encrypted_tasks', encryptedData);
    } catch (e) {
      _error = 'Failed to save tasks: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addTask(Task task) async {
    _tasks.add(task);
    notifyListeners();
    await saveTasks();
    unawaited(NotificationService.instance.scheduleTaskReminder(task));
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      final saved = updatedTask.copyWith(updatedAt: DateTime.now());
      _tasks[index] = saved;
      notifyListeners();
      await saveTasks();
      unawaited(NotificationService.instance.scheduleTaskReminder(saved));
    }
  }

  /// Soft-deletes a task (moves to trash). Use [undoDelete] to restore within
  /// the same session, or [restoreFromTrash] from the trash page.
  Future<void> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _lastDeletedTask = _tasks[index];
    _tasks[index] = _tasks[index].copyWith(deletedAt: DateTime.now());
    notifyListeners();
    await saveTasks();
    unawaited(NotificationService.instance.cancelReminder(taskId));
  }

  /// Undoes the most recent [deleteTask] call (restores from trash in-place).
  Future<void> undoDelete() async {
    final task = _lastDeletedTask;
    if (task == null) return;
    _lastDeletedTask = null;
    await restoreFromTrash(task.id);
  }

  Future<void> restoreFromTrash(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(clearDeletedAt: true);
    notifyListeners();
    await saveTasks();
  }

  Future<void> permanentlyDeleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
    await saveTasks();
    unawaited(NotificationService.instance.cancelReminder(taskId));
    // Best-effort remote tombstone so other devices learn about this deletion.
    if (SupabaseService.instance.currentUser != null) {
      unawaited(SupabaseService.instance.markEncryptedTaskItemDeleted(taskId));
    }
  }

  Future<void> archiveTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(isArchived: true, updatedAt: DateTime.now());
    notifyListeners();
    await saveTasks();
  }

  Future<void> unarchiveTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].copyWith(isArchived: false, updatedAt: DateTime.now());
    notifyListeners();
    await saveTasks();
  }

  List<Task> getTrashedTasks() {
    return _tasks.where((t) => t.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
  }

  /// Creates a copy of [taskId] with a new id, reset completion/dates, and
  /// "(Copy)" appended to the title.
  Future<void> duplicateTask(String taskId) async {
    final original = _tasks.firstWhere((t) => t.id == taskId);
    final now = DateTime.now();
    final copy = Task(
      id: now.millisecondsSinceEpoch.toString(),
      title: '${original.title} (Copy)',
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
      subTasks: original.subTasks
          .map((s) => s.copyWith(isCompleted: false))
          .toList(),
      createdAt: now,
      updatedAt: now,
    );
    _tasks.add(copy);
    notifyListeners();
    await saveTasks();
  }

  List<Task> getArchivedTasks() {
    return _tasks.where((t) => t.isArchived && t.deletedAt == null).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> toggleTaskComplete(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final task = _tasks[index];

    // For recurring tasks being marked complete: roll forward instead of
    // marking done, unless the recurrence has ended.
    if (!task.isCompleted && task.recurrence != null) {
      final next = RecurrenceService.nextOccurrence(task);
      if (next != null && !RecurrenceService.hasEnded(task.recurrence!, next)) {
        final rolled = task.copyWith(
          dueDate: next,
          clearReminderAt: true,
          subTasks: task.subTasks
              .map((s) => s.copyWith(isCompleted: false))
              .toList(),
          updatedAt: DateTime.now(),
        );
        _tasks[index] = rolled;
        notifyListeners();
        await saveTasks();
        unawaited(NotificationService.instance.scheduleTaskReminder(rolled));
        return;
      }
    }

    final completing = !task.isCompleted;
    _tasks[index] = task.copyWith(
      isCompleted: completing,
      completedAt: completing ? DateTime.now() : null,
      clearCompletedAt: !completing,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await saveTasks();
  }

  Future<void> toggleSubTaskComplete(String taskId, String subTaskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      final updatedSubTasks = task.subTasks.map((st) {
        if (st.id == subTaskId) {
          return st.copyWith(isCompleted: !st.isCompleted);
        }
        return st;
      }).toList();
      _tasks[taskIndex] = task.copyWith(
        subTasks: updatedSubTasks,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      await saveTasks();
    }
  }

  List<Task> getTasksByCategory(String? category) {
    if (category == null) {
      return _tasks;
    }
    return _tasks.where((t) => t.category == category).toList();
  }

  List<Task> getTasksByPriority(TaskPriority priority) {
    return _tasks.where((t) => t.priority == priority).toList();
  }

  List<Task> getOverdueTasks() {
    return _tasks.where((t) => t.isOverdue).toList();
  }

  List<Task> getCompletedTasks() {
    return _tasks.where((t) => t.isCompleted).toList();
  }

  List<Task> getPendingTasks() {
    return _tasks.where((t) => !t.isCompleted).toList();
  }

  List<String?> getCategories() {
    final categories = _tasks
        .where((t) => t.category != null)
        .map((t) => t.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  Future<String> getEncryptedBackupData() async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot create backup.');
    }
    final tasksJson = _tasks.map((task) => task.toJson()).toList();
    final jsonString = jsonEncode(tasksJson);
    return await EncryptionService.encryptData(jsonString);
  }

  Future<void> restoreFromBackup(String encryptedData) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot restore backup.');
    }
    try {
      final decryptedJson = await EncryptionService.decryptData(encryptedData);
      final List<dynamic> tasksJson =
          jsonDecode(decryptedJson) as List<dynamic>;
      _tasks = tasksJson
          .map((json) => Task.fromJson(json as Map<String, dynamic>))
          .toList();
      notifyListeners();
      await saveTasks();
    } on Exception {
      _error = 'Invalid password or corrupted backup data';
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to restore backup: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Decrypts [encryptedData] and computes what would change if it were
  /// applied, without modifying local state (item 25).
  Future<BackupPreview> previewBackup(String encryptedData) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot preview backup.');
    }
    final decryptedJson = await EncryptionService.decryptData(encryptedData);
    final List<dynamic> tasksJson =
        jsonDecode(decryptedJson) as List<dynamic>;
    final backupTasks = tasksJson
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();

    final localIds = {for (final t in _tasks) t.id: t};
    final backupIds = {for (final t in backupTasks) t.id: t};

    int toAdd = 0;
    int toUpdate = 0;
    for (final bt in backupTasks) {
      final local = localIds[bt.id];
      if (local == null) {
        toAdd++;
      } else if (local.updatedAt != bt.updatedAt ||
          local.title != bt.title ||
          local.isCompleted != bt.isCompleted) {
        toUpdate++;
      }
    }
    final toRemove = _tasks.where((t) => !backupIds.containsKey(t.id)).length;

    return BackupPreview(
      backupTaskCount: backupTasks.length,
      toAdd: toAdd,
      toUpdate: toUpdate,
      toRemove: toRemove,
    );
  }

  Future<void> bulkComplete(Set<String> taskIds, {required bool complete}) async {
    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          isCompleted: complete,
          updatedAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
    await saveTasks();
  }

  Future<void> bulkDelete(Set<String> taskIds) async {
    final now = DateTime.now();
    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(deletedAt: now);
        unawaited(NotificationService.instance.cancelReminder(id));
      }
    }
    notifyListeners();
    await saveTasks();
  }

  Future<void> bulkSetCategory(Set<String> taskIds, String? category) async {
    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          category: category,
          updatedAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
    await saveTasks();
  }

  Future<void> bulkSetPriority(Set<String> taskIds, TaskPriority priority) async {
    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          priority: priority,
          updatedAt: DateTime.now(),
        );
      }
    }
    notifyListeners();
    await saveTasks();
  }

  /// Performs a conflict-safe per-task merge with the cloud (item 27).
  ///
  /// Strategy: last-writer-wins per task using [Task.updatedAt].
  /// Returns a [SyncResult] summary of what changed.
  Future<SyncResult> syncTasks() async {
    final supabase = SupabaseService.instance;
    if (supabase.currentUser == null) {
      throw StateError('Cannot sync: no authenticated user.');
    }

    // 1. Fetch all remote task items (including tombstones).
    final remoteItems = await supabase.fetchEncryptedTaskItemsForCurrentUser();
    final remoteMap = <String, Map<String, dynamic>>{
      for (final r in remoteItems) r['id'] as String: r,
    };

    int uploaded = 0;
    int downloaded = 0;

    // 2. Apply remote → local (download newer / tombstoned items).
    for (final entry in remoteMap.entries) {
      final id = entry.key;
      final remote = entry.value;
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final isDeleted = remote['deleted'] as bool? ?? false;
      final localIndex = _tasks.indexWhere((t) => t.id == id);

      if (isDeleted) {
        // Propagate remote deletion only if local version isn't newer.
        if (localIndex != -1 &&
            !_tasks[localIndex].updatedAt.isAfter(remoteUpdatedAt)) {
          _tasks.removeAt(localIndex);
        }
      } else {
        final blob = remote['data_blob'] as String?;
        if (blob == null) continue;

        Task remoteTask;
        try {
          final decrypted = await EncryptionService.decryptData(blob);
          remoteTask = Task.fromJson(
            jsonDecode(decrypted) as Map<String, dynamic>,
          );
        } catch (_) {
          continue; // Skip any corrupted remote item.
        }

        if (localIndex == -1) {
          _tasks.add(remoteTask);
          downloaded++;
        } else if (remoteUpdatedAt.isAfter(_tasks[localIndex].updatedAt)) {
          _tasks[localIndex] = remoteTask;
          downloaded++;
        }
      }
    }

    // 3. Upload local tasks that are absent from remote or newer than remote.
    for (final task in List.of(_tasks)) {
      final remote = remoteMap[task.id];
      final remoteUpdatedAt = remote != null
          ? DateTime.parse(remote['updated_at'] as String)
          : null;
      final needsUpload =
          remoteUpdatedAt == null || task.updatedAt.isAfter(remoteUpdatedAt);
      if (!needsUpload) continue;

      if (task.deletedAt != null && remote != null) {
        // Soft-deleted and already known to remote: promote to tombstone.
        await supabase.markEncryptedTaskItemDeleted(task.id);
      } else if (task.deletedAt == null) {
        final encrypted = await EncryptionService.encryptData(
          jsonEncode(task.toJson()),
        );
        await supabase.upsertEncryptedTaskItem(
          id: task.id,
          dataBlob: encrypted,
          updatedAt: task.updatedAt,
        );
      }
      uploaded++;
    }

    if (downloaded > 0) {
      notifyListeners();
      await saveTasks();
    }

    return SyncResult(uploaded: uploaded, downloaded: downloaded);
  }

  /// Returns a list of (date, completionCount) entries for the last [days] days,
  /// oldest-first, based on [Task.completedAt].
  List<MapEntry<DateTime, int>> getCompletionTrend(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - (days - 1 - i));
      final count = _tasks.where((t) {
        final c = t.completedAt;
        if (c == null) return false;
        return c.year == day.year && c.month == day.month && c.day == day.day;
      }).length;
      return MapEntry(day, count);
    });
  }

  /// Priority breakdown limited to active (non-trashed, non-archived) tasks.
  Map<TaskPriority, int> get activePriorityBreakdown {
    final active = _tasks.where(
      (t) => t.deletedAt == null && !t.isArchived,
    );
    return {
      for (final p in TaskPriority.values)
        p: active.where((t) => t.priority == p).length,
    };
  }

  Future<void> clearAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('encrypted_tasks');
    _tasks = [];
    _error = null;
    notifyListeners();
  }
}
