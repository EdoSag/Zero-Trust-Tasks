import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_section.dart';

/// Renders the filtered/sorted task list either as a flat list or grouped
/// into Today/Upcoming/Overdue/Completed/No-due-date sections (item 12).
class TaskSectionList extends StatelessWidget {
  const TaskSectionList({
    super.key,
    required this.tasks,
    required this.sectioned,
    this.padding = const EdgeInsets.all(16),
  });

  final List<Task> tasks;
  final bool sectioned;
  final EdgeInsets padding;

  static const _sectionOrder = [
    TaskSection.overdue,
    TaskSection.today,
    TaskSection.upcoming,
    TaskSection.noDueDate,
    TaskSection.completed,
  ];

  @override
  Widget build(BuildContext context) {
    if (!sectioned) {
      return ListView.builder(
        padding: padding,
        itemCount: tasks.length,
        itemBuilder: (context, index) => TaskCard(task: tasks[index]),
      );
    }

    final sections = TaskFilterService.groupBySection(tasks);
    final nonEmptySections =
        _sectionOrder.where((s) => sections[s]!.isNotEmpty).toList();
    final itemCount = nonEmptySections.fold<int>(
      0,
      (sum, s) => sum + 1 + sections[s]!.length,
    );

    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        var remaining = index;
        for (final section in nonEmptySections) {
          final items = sections[section]!;
          if (remaining == 0) {
            return _SectionHeader(section: section, count: items.length);
          }
          remaining--;
          if (remaining < items.length) {
            return TaskCard(task: items[remaining]);
          }
          remaining -= items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.count});

  final TaskSection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            section.displayName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
