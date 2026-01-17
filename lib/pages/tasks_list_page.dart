import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/components/empty_tasks_widget.dart';
import 'package:zero_trust_tasks/components/task_card.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';

@NowaGenerated()
class TasksListPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const TasksListPage({super.key});

  @override
  State<TasksListPage> createState() {
    return _TasksListPageState();
  }
}

@NowaGenerated()
class _TasksListPageState extends State<TasksListPage> {
  String? _selectedCategory;

  TaskPriority? _selectedPriority;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskManager>(
      builder: (context, taskManager, child) {
        var filteredTasks = taskManager.tasks;
        if (_selectedCategory != null) {
          filteredTasks = filteredTasks
              .where((t) => t.category == _selectedCategory)
              .toList();
        }
        if (_selectedPriority != null) {
          filteredTasks = filteredTasks
              .where((t) => t.priority == _selectedPriority)
              .toList();
        }
        return Scaffold(
          body: Column(
            children: [
              if (taskManager.getCategories().isNotEmpty ||
                  _selectedCategory != null ||
                  _selectedPriority != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_selectedCategory != null ||
                            _selectedPriority != null)
                          FilterChip(
                            label: const Text('Clear'),
                            onSelected: (value) {
                              setState(() {
                                _selectedCategory = null;
                                _selectedPriority = null;
                              });
                            },
                          ),
                        const SizedBox(width: 8),
                        ...taskManager.getCategories().map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (value) {
                                setState(() {
                                  _selectedCategory = value ? category : null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: filteredTasks.isEmpty
                    ? const EmptyTasksWidget()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) =>
                            TaskCard(task: filteredTasks[index]),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTaskScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Task'),
          ),
        );
      },
    );
  }
}
