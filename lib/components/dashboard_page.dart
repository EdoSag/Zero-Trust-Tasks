import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/components/dashboard_card.dart';
import 'package:zero_trust_tasks/components/priority_breakdown.dart';
import 'package:zero_trust_tasks/components/empty_tasks_widget.dart';
import 'package:zero_trust_tasks/components/error_state_widget.dart';
import 'package:zero_trust_tasks/components/skeleton_task_card.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';
import 'package:zero_trust_tasks/pages/insights_page.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  void _openFilteredList(
    BuildContext context, {
    required String title,
    TaskFilterState filter = TaskFilterState.defaults,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TasksListPage(initialFilter: filter, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final taskManager = ref.watch(taskManagerProvider);
        if (taskManager.isLoading) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) => const SkeletonTaskCard(),
          );
        }
        if (taskManager.error != null) {
          return ErrorStateWidget(
            message: taskManager.error!,
            onRetry: () => taskManager.loadTasks(),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.overview,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  DashboardCard(
                    title: context.l10n.totalTasks,
                    value: '${taskManager.totalTasks}',
                    icon: Icons.assignment,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _openFilteredList(
                      context,
                      title: context.l10n.allTasks,
                    ),
                  ),
                  DashboardCard(
                    title: context.l10n.pending,
                    value: '${taskManager.pendingTasksCount}',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    onTap: () => _openFilteredList(
                      context,
                      title: context.l10n.pendingTasks,
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.pending,
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: context.l10n.completed,
                    value: '${taskManager.completedTasksCount}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () => _openFilteredList(
                      context,
                      title: context.l10n.completedTasks,
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.completed,
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: context.l10n.overdue,
                    value: '${taskManager.overdueTasksCount}',
                    icon: Icons.warning,
                    color: Colors.red,
                    onTap: () => _openFilteredList(
                      context,
                      title: context.l10n.overdueTasks,
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.overdue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.priorityBreakdown,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              PriorityBreakdown(priorities: taskManager.tasksByPriorityCount),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InsightsPage(),
                  ),
                ),
                icon: const Icon(Icons.insights),
                label: Text(context.l10n.viewProductivityInsights),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.recentTasks,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (taskManager.totalTasks == 0)
                EmptyTasksWidget(
                  onCreateTask: () => showQuickAdd(context),
                )
              else
                // Newest first; deleted and archived tasks don't show.
                for (final task in taskManager.recentTasks()) TaskCard(key: ValueKey(task.id), task: task),
            ],
          ),
        );
      },
    );
  }
}
