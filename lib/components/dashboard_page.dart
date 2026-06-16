import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/components/dashboard_card.dart';
import 'package:zero_trust_tasks/components/priority_breakdown.dart';
import 'package:zero_trust_tasks/components/empty_tasks_widget.dart';
import 'package:zero_trust_tasks/components/error_state_widget.dart';
import 'package:zero_trust_tasks/components/skeleton_task_card.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';

@NowaGenerated()
class DashboardPage extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
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
    return Consumer<TaskManager>(
      builder: (context, taskManager, child) {
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
                'Overview',
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
                    title: 'Total Tasks',
                    value: '${taskManager.totalTasks}',
                    icon: Icons.assignment,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _openFilteredList(
                      context,
                      title: 'All Tasks',
                    ),
                  ),
                  DashboardCard(
                    title: 'Pending',
                    value: '${taskManager.pendingTasksCount}',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    onTap: () => _openFilteredList(
                      context,
                      title: 'Pending Tasks',
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.pending,
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: 'Completed',
                    value: '${taskManager.completedTasksCount}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () => _openFilteredList(
                      context,
                      title: 'Completed Tasks',
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.completed,
                      ),
                    ),
                  ),
                  DashboardCard(
                    title: 'Overdue',
                    value: '${taskManager.overdueTasksCount}',
                    icon: Icons.warning,
                    color: Colors.red,
                    onTap: () => _openFilteredList(
                      context,
                      title: 'Overdue Tasks',
                      filter: TaskFilterState.statusFilter(
                        TaskStatusFilter.overdue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Priority Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              PriorityBreakdown(priorities: taskManager.tasksByPriorityCount),
              const SizedBox(height: 24),
              Text(
                'Recent Tasks',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (taskManager.tasks.isEmpty)
                EmptyTasksWidget(
                  onCreateTask: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddTaskScreen(),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: taskManager.tasks.length > 5
                      ? 5
                      : taskManager.tasks.length,
                  itemBuilder: (context, index) {
                    final task = taskManager.tasks[index];
                    return TaskCard(task: task);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
