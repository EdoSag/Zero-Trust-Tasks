import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.isCompleted = false,
    this.subTasks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.create({
    required String title,
    String? description,
    String? category,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    List<SubTask> subTasks = const [],
  }) {
    final now = DateTime.now();
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      category: category,
      priority: priority,
      dueDate: dueDate,
      isCompleted: false,
      subTasks: subTasks,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      subTasks:
          (json['subTasks'] as List?)
              ?.map((e) => SubTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  final String id;

  final String title;

  final String? description;

  final String? category;

  final TaskPriority priority;

  final DateTime? dueDate;

  final bool isCompleted;

  final List<SubTask> subTasks;

  final DateTime createdAt;

  final DateTime updatedAt;

  bool get isOverdue {
    if (dueDate == null || isCompleted) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }

  int get completedSubTasksCount {
    return subTasks.where((st) => st.isCompleted).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'subTasks': subTasks.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    List<SubTask>? subTasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
