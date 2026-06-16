import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/task_priority.dart';

/// A reusable task blueprint — like a Task but without runtime state (no
/// completion, dates, or archive/trash flags). Used to pre-fill [AddTaskScreen].
class TaskTemplate {
  TaskTemplate({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.priority = TaskPriority.medium,
    this.tags = const [],
    this.notes,
    this.links = const [],
    this.subTaskTitles = const [],
    this.recurrence,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;
  final TaskPriority priority;
  final List<String> tags;
  final String? notes;
  final List<String> links;

  /// Sub-task titles only — no completion state.
  final List<String> subTaskTitles;
  final RecurrenceRule? recurrence;

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      notes: json['notes'] as String?,
      links: (json['links'] as List?)?.map((e) => e as String).toList() ?? [],
      subTaskTitles:
          (json['subTaskTitles'] as List?)?.map((e) => e as String).toList() ??
          [],
      recurrence: json['recurrence'] != null
          ? RecurrenceRule.fromJson(
              json['recurrence'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority.name,
    'tags': tags,
    'notes': notes,
    'links': links,
    'subTaskTitles': subTaskTitles,
    'recurrence': recurrence?.toJson(),
  };
}
