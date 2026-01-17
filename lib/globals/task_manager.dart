import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:zero_trust_tasks/task_priority.dart';
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
      TaskPriority.critical: _tasks
          .where((t) => t.priority == TaskPriority.critical)
          .length,
      TaskPriority.high: _tasks
          .where((t) => t.priority == TaskPriority.high)
          .length,
      TaskPriority.medium: _tasks
          .where((t) => t.priority == TaskPriority.medium)
          .length,
      TaskPriority.low: _tasks
          .where((t) => t.priority == TaskPriority.low)
          .length,
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
      if (encryptedData != null && encryptedData!.isNotEmpty) {
        final decryptedJson = EncryptionService.decryptData(encryptedData);
        final List<dynamic> tasksJson =
            jsonDecode(decryptedJson) as List<dynamic>;
        _tasks = tasksJson
            .map((json) => Task.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _tasks = [];
      }
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
      final encryptedData = EncryptionService.encryptData(jsonString);
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
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask.copyWith(updatedAt: DateTime.now());
      notifyListeners();
      await saveTasks();
    }
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
    await saveTasks();
  }

  Future<void> toggleTaskComplete(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      await saveTasks();
    }
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

  List<String> getCategories() {
    final categories = _tasks
        .where((t) => t.category != null)
        .map((t) => t.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  String getEncryptedBackupData() {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot create backup.');
    }
    final tasksJson = _tasks.map((task) => task.toJson()).toList();
    final jsonString = jsonEncode(tasksJson);
    return EncryptionService.encryptData(jsonString);
  }

  Future<void> restoreFromBackup(String encryptedData) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot restore backup.');
    }
    try {
      final decryptedJson = EncryptionService.decryptData(encryptedData);
      final List<dynamic> tasksJson =
          jsonDecode(decryptedJson) as List<dynamic>;
      _tasks = tasksJson
          .map((json) => Task.fromJson(json as Map<String, dynamic>))
          .toList();
      notifyListeners();
      await saveTasks();
    } catch (e) {
      _error = 'Failed to restore backup: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }
}
