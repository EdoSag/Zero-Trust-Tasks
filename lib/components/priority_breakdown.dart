import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: TaskPriority.values.map((priority) {
            final count = priorities[priority] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      priority.displayName,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    '${count}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: priority.getColor(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
