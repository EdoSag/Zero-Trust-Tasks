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
import 'package:zero_trust_tasks/components/task_calendar_view.dart';
import 'package:zero_trust_tasks/components/task_section_list.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority.dart';
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
  bool _calendarView = false;
  bool _selectionMode = false;
  Set<String> _selectedTaskIds = {};

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

  void _enterSelectionMode(String taskId) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds = {taskId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTaskIds = {};
    });
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds = Set.of(_selectedTaskIds)..remove(taskId);
        if (_selectedTaskIds.isEmpty) _selectionMode = false;
      } else {
        _selectedTaskIds = Set.of(_selectedTaskIds)..add(taskId);
      }
    });
  }

  void _selectAll(List<Task> tasks) {
    setState(() {
      _selectedTaskIds = tasks.map((t) => t.id).toSet();
    });
  }

  Future<void> _bulkComplete(BuildContext ctx) async {
    await TaskManager.of(ctx).bulkComplete(_selectedTaskIds, complete: true);
    _exitSelectionMode();
  }

  Future<void> _bulkDelete(BuildContext ctx) async {
    await TaskManager.of(ctx).bulkDelete(_selectedTaskIds);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('${_selectedTaskIds.length} tasks moved to trash'),
        ),
      );
    }
    _exitSelectionMode();
  }

  Future<void> _bulkSetCategory(
    BuildContext ctx,
    List<String> categories,
  ) async {
    final result = await showDialog<String?>(
      context: ctx,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Set category'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dCtx, ''),
            child: Text(
              'None',
              style: TextStyle(
                color: Theme.of(dCtx).colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
          ),
          ...categories.map(
            (c) => SimpleDialogOption(
              onPressed: () => Navigator.pop(dCtx, c),
              child: Text(c),
            ),
          ),
        ],
      ),
    );
    if (result == null || !ctx.mounted) return;
    await TaskManager.of(ctx).bulkSetCategory(
      _selectedTaskIds,
      result.isEmpty ? null : result,
    );
    _exitSelectionMode();
  }

  Future<void> _bulkSetPriority(BuildContext ctx) async {
    final result = await showDialog<TaskPriority>(
      context: ctx,
      builder: (dCtx) => SimpleDialog(
        title: const Text('Set priority'),
        children: TaskPriority.values
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dCtx, p),
                child: Row(
                  children: [
                    Icon(p.icon, size: 16),
                    const SizedBox(width: 8),
                    Text(p.displayName),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (result == null || !ctx.mounted) return;
    await TaskManager.of(ctx).bulkSetPriority(_selectedTaskIds, result);
    _exitSelectionMode();
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
        final categories =
            taskManager.getCategories().whereType<String>().toList();

        List<Task> sorted = [];
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
          sorted = TaskFilterService.sortTasks(
            filtered,
            _filterState.sortOption,
          );
          if (sorted.isEmpty) {
            body = EmptyTasksWidget(
              reason: EmptyTasksReason.noMatchingFilters,
              onClearFilters: () => _updateFilter(_filterState.clearFilters()),
            );
          } else if (_calendarView) {
            body = TaskCalendarView(tasks: sorted);
          } else {
            body = TaskSectionList(
              tasks: sorted,
              sectioned: _sectioned,
              selectionMode: _selectionMode,
              selectedTaskIds: _selectedTaskIds,
              onLongPress: _enterSelectionMode,
              onToggleSelection: _toggleSelection,
            );
          }
        }

        AppBar? appBar;
        if (_selectionMode) {
          final allSelected =
              sorted.isNotEmpty &&
              _selectedTaskIds.length == sorted.length;
          appBar = AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: _exitSelectionMode,
            ),
            title: Text(
              _selectedTaskIds.isEmpty
                  ? 'Select tasks'
                  : '${_selectedTaskIds.length} selected',
            ),
            actions: [
              TextButton(
                onPressed: allSelected
                    ? () => setState(() => _selectedTaskIds = {})
                    : () => _selectAll(sorted),
                child: Text(allSelected ? 'None' : 'All'),
              ),
            ],
          );
        } else if (widget.initialFilter != null) {
          appBar = AppBar(title: Text(_resolveTitle()));
        }

        return Scaffold(
          appBar: appBar,
          body: Column(
            children: [
              if (!_selectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TaskSearchBar(
                          initialValue: _filterState.searchQuery,
                          onChanged: (value) {
                            _updateFilter(
                              _filterState.copyWith(searchQuery: value),
                            );
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
                      if (!_calendarView)
                        IconButton(
                          icon: Icon(
                            _sectioned ? Icons.view_agenda : Icons.view_list,
                          ),
                          tooltip: _sectioned
                              ? 'Switch to flat list'
                              : 'Switch to sectioned list',
                          onPressed: _toggleSectioned,
                        ),
                      IconButton(
                        icon: Icon(
                          _calendarView
                              ? Icons.list
                              : Icons.calendar_month_outlined,
                        ),
                        tooltip: _calendarView
                            ? 'Switch to list'
                            : 'Switch to calendar',
                        onPressed: () => setState(() {
                          _calendarView = !_calendarView;
                          if (_calendarView) {
                            _selectionMode = false;
                            _selectedTaskIds = {};
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: _selectionMode
              ? _BulkActionBar(
                  enabled: _selectedTaskIds.isNotEmpty,
                  onComplete: () => _bulkComplete(context),
                  onDelete: () => _bulkDelete(context),
                  onCategory: () => _bulkSetCategory(context, categories),
                  onPriority: () => _bulkSetPriority(context),
                )
              : null,
          floatingActionButton: _selectionMode
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openAddTask,
                  icon: const Icon(Icons.add),
                  label: const Text('New Task'),
                ),
        );
      },
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.enabled,
    required this.onComplete,
    required this.onDelete,
    required this.onCategory,
    required this.onPriority,
  });

  final bool enabled;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onCategory;
  final VoidCallback onPriority;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BulkButton(
            icon: Icons.check_circle_outline,
            label: 'Complete',
            enabled: enabled,
            onTap: onComplete,
          ),
          _BulkButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            enabled: enabled,
            onTap: onDelete,
            destructive: true,
          ),
          _BulkButton(
            icon: Icons.label_outline,
            label: 'Category',
            enabled: enabled,
            onTap: onCategory,
          ),
          _BulkButton(
            icon: Icons.flag_outlined,
            label: 'Priority',
            enabled: enabled,
            onTap: onPriority,
          ),
        ],
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  const _BulkButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Theme.of(context).disabledColor
        : destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
