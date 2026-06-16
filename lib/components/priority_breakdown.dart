import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';

@NowaGenerated()
class PriorityBreakdown extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const PriorityBreakdown({super.key, required this.priorities});

  final Map<TaskPriority, int> priorities;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: TaskPriority.values.map((priority) {
            final count = priorities[priority] ?? 0;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TasksListPage(
                      initialFilter: TaskFilterState.priorityFilter(priority),
                      title: '${priority.displayName} Priority Tasks',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: priority.getColor(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      priority.icon,
                      size: 16,
                      color: priority.getColor(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        priority.displayName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: priority.getColor(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
