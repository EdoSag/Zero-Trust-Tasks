import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// The fields ZT Calendar's Planner reads from a task: how long it takes,
/// whether to plan it, block sizes and which hours. ZT Calendar writes them
/// too (from its Planner screen), so their names and meaning are shared.
///
/// They live in the task's [Task.extra], like any key a version doesn't
/// know: a task that never used them looks exactly as before, and an older
/// ZT Tasks keeps them unchanged when it saves the task.
extension TaskPlan on Task {
  static const minutesKey = 'planMinutes';
  static const minChunkKey = 'planMinChunk';
  static const maxChunkKey = 'planMaxChunk';
  static const autoKey = 'planAuto';
  static const hoursKey = 'planHours';
  static const keys = {minutesKey, minChunkKey, maxChunkKey, autoKey, hoursKey};

  /// The hours a task is planned in: work hours unless set to personal.
  static const workHours = 'work';
  static const personalHours = 'personal';

  /// Longest length that can be set: a week of work, as ZT Calendar allows.
  static const maxMinutes = 7 * 24 * 60;

  static int? _minutes(Object? raw) =>
      raw is num && raw > 0 ? raw.toInt().clamp(5, maxMinutes) : null;

  /// How long the task takes, in minutes; null when not set (the Planner
  /// then uses its usual length).
  int? get planMinutes => _minutes(extra[minutesKey]);
  int? get planMinChunk => _minutes(extra[minChunkKey]);
  int? get planMaxChunk => _minutes(extra[maxChunkKey]);

  /// True switched on, false switched off, null never chosen (planned only
  /// when ZT Calendar plans every task).
  bool? get planAuto => extra[autoKey] is bool ? extra[autoKey] as bool : null;

  /// Planned in personal hours rather than work hours.
  bool get planPersonal => extra[hoursKey] == personalHours;

  bool get hasPlanFields => keys.any(extra.containsKey);

  /// The same task with the Planner's fields in [changes] set; a null value
  /// removes the field. Every other key stays as it is.
  Task withPlan(Map<String, Object?> changes) {
    assert(changes.keys.every(keys.contains), 'Not a Planner field: ${changes.keys}');
    final next = {...extra};
    for (final e in changes.entries) {
      if (e.value == null) {
        next.remove(e.key);
      } else {
        next[e.key] = e.value;
      }
    }
    return copyWith(extra: next);
  }

  /// The Planner's fields as they are on this task, for an editor to start
  /// from. Only the ones that are set.
  Map<String, Object?> get planFields => {
        for (final k in keys)
          if (extra.containsKey(k)) k: extra[k],
      };

  /// A new task put in [list]: switched on for the Planner when the list
  /// says every new task is, unless it was already switched on or off.
  Task forNewIn(TaskList list) =>
      list.autoPlan && planAuto == null ? withPlan({autoKey: true}) : this;
}
