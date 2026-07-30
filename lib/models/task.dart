import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:uuid/uuid.dart';

@NowaGenerated()
class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.priority = TaskPriority.medium,
    this.startDate,
    this.dueDate,
    this.reminderAt,
    this.recurrence,
    this.tags = const [],
    this.notes,
    this.links = const [],
    this.isCompleted = false,
    this.isArchived = false,
    this.deletedAt,
    this.completedAt,
    this.subTasks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.create({
    required String title,
    String? description,
    String? category,
    TaskPriority priority = TaskPriority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? reminderAt,
    RecurrenceRule? recurrence,
    List<String> tags = const [],
    String? notes,
    List<String> links = const [],
    List<SubTask> subTasks = const [],
  }) {
    final now = DateTime.now();
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      category: category,
      priority: priority,
      startDate: startDate,
      dueDate: dueDate,
      reminderAt: reminderAt,
      recurrence: recurrence,
      tags: tags,
      notes: notes,
      links: links,
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
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      reminderAt: json['reminderAt'] != null
          ? DateTime.parse(json['reminderAt'] as String)
          : null,
      recurrence: json['recurrence'] != null
          ? RecurrenceRule.fromJson(json['recurrence'] as Map<String, dynamic>)
          : null,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
      notes: json['notes'] as String?,
      links: (json['links'] as List?)?.map((e) => e as String).toList() ?? const [],
      isCompleted: json['isCompleted'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
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

  final DateTime? startDate;

  final DateTime? dueDate;

  final DateTime? reminderAt;

  final RecurrenceRule? recurrence;

  final List<String> tags;

  final String? notes;

  final List<String> links;

  final bool isCompleted;

  final bool isArchived;

  /// Non-null means the task is soft-deleted (in trash). Purged after 30 days.
  final DateTime? deletedAt;

  /// When non-null, records the instant this task was last marked complete.
  final DateTime? completedAt;

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
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'recurrence': recurrence?.toJson(),
      'tags': tags,
      'notes': notes,
      'links': links,
      'isCompleted': isCompleted,
      'isArchived': isArchived,
      'deletedAt': deletedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
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
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? reminderAt,
    bool clearReminderAt = false,
    RecurrenceRule? recurrence,
    bool clearRecurrence = false,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
    List<String>? links,
    bool? isCompleted,
    bool? isArchived,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
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
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
      links: links ?? this.links,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      subTasks: subTasks ?? this.subTasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
