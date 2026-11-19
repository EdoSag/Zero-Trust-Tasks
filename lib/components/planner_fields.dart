import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart' show describeDue;
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_plan.dart';
import 'package:zero_trust_tasks/suite/linked_app_launcher.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';
import 'package:zero_trust_tasks/suite/planned_times.dart';

/// "45 min", "2 h", "1 h 30 min".
String formatPlanLength(AppL10n l, int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l.lengthMinutes(m);
  if (m == 0) return l.lengthHours(h);
  return l.lengthHoursMinutes(h, m);
}

/// Lengths offered for a task.
const planLengthChoices = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480];

/// Block sizes offered for the shortest and longest block.
const planChunkChoices = [15, 30, 45, 60, 90, 120, 180, 240];

/// The Planner's part of the task editor: Length, Auto-schedule, and under
/// "Planner options" the shortest and longest block and which hours.
///
/// [fields] holds the Planner's fields as the task will store them (see
/// [TaskPlan]); every change gives the whole map back.
class PlannerFieldsSection extends StatelessWidget {
  const PlannerFieldsSection({super.key, required this.fields, required this.onChanged});

  final Map<String, Object?> fields;
  final ValueChanged<Map<String, Object?>> onChanged;

  int? _minutes(String key) {
    final raw = fields[key];
    return raw is num && raw > 0 ? raw.toInt() : null;
  }

  void _set(String key, Object? value) {
    final next = {...fields};
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: theme.dividerColor),
    );
    final length = _minutes(TaskPlan.minutesKey);
    final minChunk = _minutes(TaskPlan.minChunkKey);
    final maxChunk = _minutes(TaskPlan.maxChunkKey);
    final auto = fields[TaskPlan.autoKey] is bool ? fields[TaskPlan.autoKey] as bool : null;
    final personal = fields[TaskPlan.hoursKey] == TaskPlan.personalHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('plan-length'),
          leading: const Icon(Icons.timelapse),
          title: Text(length == null ? l.noLength : l.lengthIs(formatPlanLength(l, length))),
          subtitle: Text(l.lengthHint),
          trailing: length == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l.clearLength,
                  onPressed: () => _set(TaskPlan.minutesKey, null),
                ),
          shape: border,
          onTap: () async {
            final picked = await pickPlanMinutes(
              context,
              title: l.taskLength,
              choices: planLengthChoices,
              current: length,
            );
            if (picked != null) _set(TaskPlan.minutesKey, picked);
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('plan-auto'),
          secondary: const Icon(Icons.auto_awesome_outlined),
          title: Text(l.autoSchedule),
          subtitle: Text(switch (auto) {
            true => l.autoScheduleOn,
            false => l.autoScheduleOff,
            null => l.autoScheduleUnset,
          }),
          value: auto == true,
          shape: border,
          onChanged: (on) => _set(TaskPlan.autoKey, on),
        ),
        const SizedBox(height: 12),
        Theme(
          // No lines above and below the open section.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('plan-options'),
            leading: const Icon(Icons.tune),
            title: Text(l.plannerOptions),
            shape: border,
            collapsedShape: border,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ListTile(
                key: const ValueKey('plan-min-chunk'),
                title: Text(l.shortestBlock),
                trailing: Text(minChunk == null ? l.plannerUsual : formatPlanLength(l, minChunk)),
                onTap: () async {
                  final picked = await pickPlanMinutes(
                    context,
                    title: l.shortestBlock,
                    choices: planChunkChoices,
                    current: minChunk,
                    usual: true,
                  );
                  if (picked == null) return;
                  final value = picked == 0 ? null : picked;
                  final next = {...fields};
                  value == null ? next.remove(TaskPlan.minChunkKey) : next[TaskPlan.minChunkKey] = value;
                  // The longest block is never shorter than the shortest.
                  if (value != null && maxChunk != null && maxChunk < value) next.remove(TaskPlan.maxChunkKey);
                  onChanged(next);
                },
              ),
              ListTile(
                key: const ValueKey('plan-max-chunk'),
                title: Text(l.longestBlock),
                trailing: Text(maxChunk == null ? l.plannerUsual : formatPlanLength(l, maxChunk)),
                onTap: () async {
                  final picked = await pickPlanMinutes(
                    context,
                    title: l.longestBlock,
                    choices: [for (final c in planChunkChoices) if (minChunk == null || c >= minChunk) c],
                    current: maxChunk,
                    usual: true,
                  );
                  if (picked != null) _set(TaskPlan.maxChunkKey, picked == 0 ? null : picked);
                },
              ),
              ListTile(
                key: const ValueKey('plan-hours'),
                title: Text(l.plannerHours),
                trailing: Text(personal ? l.personalHours : l.workHours),
                onTap: () async {
                  final picked = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => SimpleDialog(
                      title: Text(l.plannerHours),
                      children: [
                        for (final (value, label) in [(false, l.workHours), (true, l.personalHours)])
                          SimpleDialogOption(
                            onPressed: () => Navigator.of(dialog).pop(value),
                            child: Row(
                              children: [
                                Icon(value == personal ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                                const SizedBox(width: 16),
                                Expanded(child: Text(label)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                  // Work hours are what a task without the field gets.
                  if (picked != null) _set(TaskPlan.hoursKey, picked ? TaskPlan.personalHours : null);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks for a length from [choices]. With [usual], the first choice is
/// "Usual" (returned as 0: the Planner's own setting).
Future<int?> pickPlanMinutes(
  BuildContext context, {
  required String title,
  required List<int> choices,
  int? current,
  bool usual = false,
}) {
  final l = context.l10n;
  return showDialog<int>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(title),
      children: [
        for (final m in [if (usual) 0, ...choices])
          SimpleDialogOption(
            key: ValueKey('plan-choice-$m'),
            onPressed: () => Navigator.of(dialog).pop(m),
            child: Row(
              children: [
                Icon((current ?? 0) == m ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                const SizedBox(width: 16),
                Expanded(child: Text(m == 0 ? l.plannerUsual : formatPlanLength(l, m))),
              ],
            ),
          ),
      ],
    ),
  );
}

/// "Planned Tue 10:00 · 1 h of 3 h done" on a task card, from ZT
/// Calendar's Planner. Nothing when the Planner has no time for the task.
class PlannedChip extends ConsumerWidget {
  const PlannedChip({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task.isCompleted) return const SizedBox.shrink();
    final info = plannedInfoFor(ref, task);
    if (info == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          key: ValueKey('planned-chip-${task.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  plannedSummary(context.l10n, info),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Planned Tomorrow 10:00 · 1 h of 3 h done", or only one of the two.
String plannedSummary(AppL10n l, TaskPlanInfo info, {DateTime? now}) {
  final parts = [
    if (info.next case final next?) l.plannedAt(describeDue(next.start, true, now: now)),
    if (info.doneMinutes > 0)
      info.totalMinutes == null
          ? l.plannedDone(formatPlanLength(l, info.doneMinutes))
          : l.plannedDoneOf(formatPlanLength(l, info.doneMinutes), formatPlanLength(l, info.totalMinutes!)),
  ];
  return parts.join(' · ');
}

/// The Planner's rows on a task's page: length, Auto-schedule and the
/// planned times, with a way to ZT Calendar. Nothing for a task the
/// Planner has never heard of.
class PlannerDetailsRows extends ConsumerWidget {
  const PlannerDetailsRows({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = plannedInfoFor(ref, task);
    if (!task.hasPlanFields && info == null) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final length = task.planMinutes;
    final auto = task.planAuto;
    Widget row(IconData icon, String label, String value, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.titleSmall),
              Expanded(child: Text(value)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (length != null)
          row(Icons.timelapse, l.lengthLabel, formatPlanLength(l, length), key: const ValueKey('details-length')),
        if (auto != null)
          row(
            Icons.auto_awesome_outlined,
            l.autoScheduleLabel,
            auto ? l.planSwitchedOn : l.planSwitchedOff,
            key: const ValueKey('details-auto'),
          ),
        if (info != null) ...[
          row(
            Icons.event_available,
            l.plannedLabel,
            [
              if (info.next case final next?)
                '${describeDue(next.start, true)}–${DateFormat('HH:mm').format(next.end)}',
              if (info.upcoming > 1) l.plannedMore(info.upcoming - 1),
              if (info.doneMinutes > 0)
                info.totalMinutes == null
                    ? l.plannedDone(formatPlanLength(l, info.doneMinutes))
                    : l.plannedDoneOf(formatPlanLength(l, info.doneMinutes), formatPlanLength(l, info.totalMinutes!)),
            ].join(' · '),
            key: const ValueKey('details-planned'),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.openZtCalendar),
              onPressed: () => openLinkedApp(LinkedApp.calendar),
            ),
          ),
        ],
      ],
    );
  }
}
