import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_plan.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';

/// A time ZT Calendar's Planner set aside for a task: an event in its
/// Planned calendar, marked with the task's id.
@immutable
class PlannedBlock {
  const PlannedBlock({
    required this.taskId,
    required this.start,
    required this.end,
    this.done = false,
    this.locked = false,
    this.occurrence,
  });

  final String taskId;
  final DateTime start;
  final DateTime end;
  final bool done;
  final bool locked;

  /// For a repeating task: the due date of the occurrence the block was for.
  final String? occurrence;

  int get minutes => end.difference(start).inMinutes;

  /// The Planned calendar's id in ZT Calendar.
  static const calendarId = 'planner';

  /// A block from a ZT Calendar item, or null for anything else.
  static PlannedBlock? fromItem(Map<String, Object?>? json) {
    if (json == null || json['kind'] != 'event' || json['calendarId'] != calendarId) return null;
    final plan = json['plan'];
    if (plan is! Map) return null;
    final taskId = plan['taskId'];
    if (plan['type'] == 'habit' || taskId is! String || taskId.isEmpty) return null;
    DateTime? time(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    final start = time(json['start']);
    final end = time(json['end']);
    if (start == null || end == null || !end.isAfter(start)) return null;
    return PlannedBlock(
      taskId: taskId,
      start: start,
      end: end,
      done: plan['done'] == true,
      locked: plan['locked'] == true,
      occurrence: plan['occurrence'] is String ? plan['occurrence'] as String : null,
    );
  }
}

/// What the Planner has done for one task: its next block and how much of
/// its time is done.
@immutable
class TaskPlanInfo {
  const TaskPlanInfo({this.next, this.doneMinutes = 0, this.upcoming = 0, this.totalMinutes});

  /// The first block not done yet that hasn't ended, or null.
  final PlannedBlock? next;
  final int doneMinutes;

  /// Blocks still to come, [next] included.
  final int upcoming;

  /// The task's length, when it has one.
  final int? totalMinutes;

  bool get isEmpty => next == null && doneMinutes == 0;

  /// [task]'s info from [blocks] (all of the task's blocks). For a
  /// repeating task only the blocks of the occurrence it is on now count.
  static TaskPlanInfo of(Task task, List<PlannedBlock> blocks, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final occurrence = task.recurrence == null ? null : task.dueDate?.toIso8601String();
    final mine = [
      for (final b in blocks)
        if (b.occurrence == null || occurrence == null || _sameOccurrence(b.occurrence!, occurrence)) b,
    ];
    final ahead = [for (final b in mine) if (!b.done && b.end.isAfter(at)) b]
      ..sort((a, b) => a.start.compareTo(b.start));
    return TaskPlanInfo(
      next: ahead.firstOrNull,
      upcoming: ahead.length,
      doneMinutes: mine.where((b) => b.done).fold(0, (sum, b) => sum + b.minutes),
      totalMinutes: task.planMinutes,
    );
  }

  /// ZT Tasks writes due dates as local ISO strings; compare the moment
  /// they name, so a different spelling of the same time still matches.
  static bool _sameOccurrence(String a, String b) {
    final x = DateTime.tryParse(a);
    final y = DateTime.tryParse(b);
    return x != null && y != null ? x.isAtSameMomentAs(y) : a == b;
  }
}

/// Whether Tasks reads ZT Calendar's Planner at all: once a task has a
/// Planner field (a length, or Auto-schedule switched on or off) or a list
/// plans its new tasks. Until then Calendar's items are never fetched.
final plannerInUseProvider = Provider<bool>((ref) {
  final tasks = ref.watch(taskManagerProvider).tasks;
  final lists = ref.watch(taskListProvider).lists;
  return lists.any((l) => l.autoPlan) ||
      tasks.any((t) => t.deletedAt == null && !t.isArchived && t.hasPlanFields);
});

/// The Planner's blocks by task id, from ZT Calendar. Empty while the
/// Planner isn't used here.
final plannedBlocksProvider = StreamProvider<Map<String, List<PlannedBlock>>>((ref) async* {
  if (!ref.watch(plannerInUseProvider)) {
    yield const {};
    return;
  }
  await for (final items in linkedItems(ref, LinkedApp.calendar)) {
    final byTask = <String, List<PlannedBlock>>{};
    for (final i in items) {
      final b = PlannedBlock.fromItem(i.json);
      if (b != null) (byTask[b.taskId] ??= []).add(b);
    }
    yield byTask;
  }
});

/// [task]'s planned times, or null when the Planner has none for it.
TaskPlanInfo? plannedInfoFor(WidgetRef ref, Task task) {
  final blocks = ref.watch(plannedBlocksProvider).value?[task.id];
  if (blocks == null || blocks.isEmpty) return null;
  final info = TaskPlanInfo.of(task, blocks);
  return info.isEmpty ? null : info;
}
