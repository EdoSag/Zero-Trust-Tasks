import 'dart:convert';

enum PendingTaskActionType { complete, snooze }

/// A tap on a reminder's Complete/Snooze button or a home-screen widget
/// tick, made while the vault may be locked. Only the task's id (and the
/// snooze time) is kept, unencrypted, until the next unlock applies it.
class PendingTaskAction {
  const PendingTaskAction({
    required this.type,
    required this.taskId,
    this.until,
    required this.at,
    this.fromWidget = false,
  });

  /// A widget tick (kept by the widget's own code, not in this queue).
  final bool fromWidget;

  final PendingTaskActionType type;
  final String taskId;

  /// New reminder time, for [PendingTaskActionType.snooze].
  final DateTime? until;
  final DateTime at;

  static PendingTaskAction? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = PendingTaskActionType.values.byName(json['type'] as String);
      return PendingTaskAction(
        type: type,
        taskId: json['taskId'] as String,
        until: json['until'] == null ? null : DateTime.parse(json['until'] as String),
        at: json['at'] == null ? DateTime.now() : DateTime.parse(json['at'] as String),
      );
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode({
        'type': type.name,
        'taskId': taskId,
        if (until != null) 'until': until!.toIso8601String(),
        'at': at.toIso8601String(),
      });
}
