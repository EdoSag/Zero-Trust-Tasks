import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/globals/settings_provider.dart';
import 'package:zero_trust_tasks/components/empty_tasks_widget.dart';
import 'package:zero_trust_tasks/components/error_state_widget.dart';
import 'package:zero_trust_tasks/components/skeleton_task_card.dart';
import 'package:zero_trust_tasks/components/task_filter_sheet.dart';
import 'package:zero_trust_tasks/components/task_search_bar.dart';
import 'package:zero_trust_tasks/components/task_section_list.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

@NowaGenerated()
class TasksListPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const TasksListPage({super.key, this.initialFilter, this.title});

  /// When provided, the page opens pre-filtered (e.g. from a dashboard
  /// card) and is shown as its own screen with a back button. The
  /// resulting filter is not persisted (item 2).
  final TaskFilterState? initialFilter;

  /// Title shown in the AppBar when [initialFilter] is provided.
  final String? title;

  @override
  State<TasksListPage> createState() {
    return _TasksListPageState();
  }
}

@NowaGenerated()
class _TasksListPageState extends State<TasksListPage> {
  late TaskFilterState _filterState;
  late bool _sectioned;
  late bool _persistFilter;

  @override
  void initState() {
    super.initState();
    _persistFilter = widget.initialFilter == null;
    if (widget.initialFilter != null) {
      _filterState = widget.initialFilter!;
      _sectioned = true;
      return;
    }
    final settings = SettingsProvider.of(context, listen: false);
    final storedJson = settings.taskFilterStateJson;
    if (storedJson != null) {
      try {
        _filterState = TaskFilterState.fromJson(
          jsonDecode(storedJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _filterState = TaskFilterState.defaults;
      }
    } else {
      _filterState = TaskFilterState.defaults;
    }
    _sectioned = !settings.taskSectionsCollapsed;
  }

  void _updateFilter(TaskFilterState newState) {
    setState(() {
      _filterState = newState;
    });
    if (_persistFilter) {
      SettingsProvider.of(context, listen: false).setTaskFilterStateJson(
        jsonEncode(newState.toJson()),
      );
    }
  }

  void _toggleSectioned() {
    setState(() {
      _sectioned = !_sectioned;
    });
    if (_persistFilter) {
      SettingsProvider.of(context, listen: false).setTaskSectionsCollapsed(
        !_sectioned,
      );
    }
  }

  Future<void> _openFilterSheet(List<String> categories) async {
    final result = await showModalBottomSheet<TaskFilterState>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TaskFilterSheet(
        filterState: _filterState,
        categories: categories,
      ),
    );
    if (result != null) {
      _updateFilter(result);
    }
  }

  void _openAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
  }

  String _resolveTitle() {
    if (widget.title != null) {
      return widget.title!;
    }
    if (_filterState.statuses.length == 1) {
      switch (_filterState.statuses.first) {
        case TaskStatusFilter.pending:
          return 'Pending Tasks';
        case TaskStatusFilter.completed:
          return 'Completed Tasks';
        case TaskStatusFilter.overdue:
          return 'Overdue Tasks';
        case TaskStatusFilter.today:
          return 'Due Today';
        case TaskStatusFilter.upcoming:
          return 'Upcoming Tasks';
      }
    }
    if (_filterState.priorities.length == 1) {
      return '${_filterState.priorities.first.displayName} Priority Tasks';
    }
    return 'Tasks';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskManager>(
      builder: (context, taskManager, child) {
        final categories = taskManager.getCategories().whereType<String>().toList();

        Widget body;
        if (taskManager.isLoading) {
          body = ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (context, index) => const SkeletonTaskCard(),
          );
        } else if (taskManager.error != null) {
          body = ErrorStateWidget(
            message: taskManager.error!,
            onRetry: () => taskManager.loadTasks(),
          );
        } else if (taskManager.tasks.isEmpty) {
          body = EmptyTasksWidget(
            reason: EmptyTasksReason.noTasksAtAll,
            onCreateTask: _openAddTask,
          );
        } else {
          final filtered = TaskFilterService.applyFilters(
            taskManager.tasks,
            _filterState,
          );
          final sorted = TaskFilterService.sortTasks(
            filtered,
            _filterState.sortOption,
          );
          if (sorted.isEmpty) {
            body = EmptyTasksWidget(
              reason: EmptyTasksReason.noMatchingFilters,
              onClearFilters: () => _updateFilter(_filterState.clearFilters()),
            );
          } else {
            body = TaskSectionList(tasks: sorted, sectioned: _sectioned);
          }
        }

        return Scaffold(
          appBar: widget.initialFilter != null
              ? AppBar(title: Text(_resolveTitle()))
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TaskSearchBar(
                        initialValue: _filterState.searchQuery,
                        onChanged: (value) {
                          _updateFilter(_filterState.copyWith(searchQuery: value));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _filterState.activeFilterCount > 0,
                      label: Text('${_filterState.activeFilterCount}'),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filter and sort',
                        onPressed: () => _openFilterSheet(categories),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _sectioned ? Icons.view_agenda : Icons.view_list,
                      ),
                      tooltip: _sectioned
                          ? 'Switch to flat list'
                          : 'Switch to sectioned list',
                      onPressed: _toggleSectioned,
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTask,
            icon: const Icon(Icons.add),
            label: const Text('New Task'),
          ),
        );
      },
    );
  }
}
