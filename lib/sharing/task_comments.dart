import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// Who a task of a shared list is assigned to (T-2). Keys in the task's
/// [Task.extra], so a task nobody assigned looks exactly as before, and
/// older versions keep them when they save the task.
extension TaskAssignment on Task {
  static const assigneeKey = 'assigneeId';
  static const byKey = 'assignedBy';
  static const atKey = 'assignedAt';

  /// The member's user id, or null.
  String? get assigneeId => extra[assigneeKey] is String ? extra[assigneeKey] as String : null;

  /// Who assigned it.
  String? get assignedBy => extra[byKey] is String ? extra[byKey] as String : null;

  DateTime? get assignedAt => extra[atKey] is String ? DateTime.tryParse(extra[atKey] as String) : null;

  /// Assigned to [userId] by [by] at [at]; null [userId] takes it off.
  Task assignedTo(String? userId, {required String by, DateTime? at}) {
    final next = Map<String, dynamic>.of(extra)
      ..remove(assigneeKey)
      ..remove(byKey)
      ..remove(atKey);
    if (userId != null) {
      next[assigneeKey] = userId;
      next[byKey] = by;
      next[atKey] = (at ?? DateTime.now()).toUtc().toIso8601String();
    }
    return copyWith(extra: next);
  }
}

/// A comment on a task of a shared list. Each comment is its own item in
/// the list's space (`comment/<taskId>/<id>`, kind `task_comment`), so two
/// people commenting at once never overwrite each other, and the task
/// itself stays as it was. Older versions of Tasks skip these items.
class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.text,
    required this.by,
    required this.at,
  });

  factory TaskComment.create({required String taskId, required String text, required String by, DateTime? at}) =>
      TaskComment(
        id: 'comment/$taskId/${const Uuid().v4()}',
        taskId: taskId,
        text: text,
        by: by,
        at: at ?? DateTime.now(),
      );

  factory TaskComment.fromJson(String id, Map<String, Object?> json) => TaskComment(
        id: id,
        taskId: json['taskId'] as String? ?? '',
        text: json['text'] as String? ?? '',
        by: json['by'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// The item id.
  final String id;
  final String taskId;
  final String text;

  /// The member's user id.
  final String by;
  final DateTime at;

  /// Longest comment kept.
  static const maxLength = 2000;

  Map<String, Object?> toJson() => {
        'taskId': taskId,
        'text': text,
        'by': by,
        'at': at.toUtc().toIso8601String(),
      };
}

final taskCommentsCollection = ZtCollection<TaskComment>(
  kind: 'task_comment',
  version: 1,
  fromJson: (id, json, _) => TaskComment.fromJson(id, json),
  toJson: (c) => c.toJson(),
  idOf: (c) => c.id,
);

/// Tasks newly assigned to [myUserId] by someone else, that haven't been
/// announced yet ([seen] holds `taskId@assignedAt` of those that were).
/// Done tasks and assignments older than [maxAge] are not announced.
List<Task> newAssignments(
  Iterable<Task> tasks, {
  required String myUserId,
  required Set<String> seen,
  required DateTime now,
  Duration maxAge = const Duration(days: 3),
}) =>
    [
      for (final t in tasks)
        if (t.assigneeId == myUserId &&
            t.assignedBy != null &&
            t.assignedBy != myUserId &&
            !t.isCompleted &&
            t.deletedAt == null &&
            t.assignedAt != null &&
            now.difference(t.assignedAt!) < maxAge &&
            !seen.contains(assignmentKey(t)))
          t,
    ];

String assignmentKey(Task t) => '${t.id}@${t.extra[TaskAssignment.atKey]}';
