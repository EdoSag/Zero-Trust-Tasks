import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/models/task_sort_option.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';

/// Describes the current search/filter/sort configuration of the tasks
/// list. Persisted (minus [searchQuery]) so the user's view survives an
/// app restart.
class TaskFilterState {
  const TaskFilterState({
    this.searchQuery = '',
    this.category,
    this.priorities = const {},
    this.statuses = const {},
    this.sortOption = TaskSortOption.dueDateAsc,
  });

  final String searchQuery;
  final String? category;
  final Set<TaskPriority> priorities;
  final Set<TaskStatusFilter> statuses;
  final TaskSortOption sortOption;

  static const TaskFilterState defaults = TaskFilterState();

  factory TaskFilterState.statusFilter(TaskStatusFilter status) {
    return TaskFilterState(statuses: {status});
  }

  factory TaskFilterState.priorityFilter(TaskPriority priority) {
    return TaskFilterState(priorities: {priority});
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        category != null ||
        priorities.isNotEmpty ||
        statuses.isNotEmpty;
  }

  /// Number of active filter "chips" (excludes free-text search).
  int get activeFilterCount {
    return (category != null ? 1 : 0) + priorities.length + statuses.length;
  }

  TaskFilterState copyWith({
    String? searchQuery,
    String? category,
    bool clearCategory = false,
    Set<TaskPriority>? priorities,
    Set<TaskStatusFilter>? statuses,
    TaskSortOption? sortOption,
  }) {
    return TaskFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      category: clearCategory ? null : (category ?? this.category),
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  TaskFilterState clearFilters() {
    return TaskFilterState(searchQuery: searchQuery, sortOption: sortOption);
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'priorities': priorities.map((p) => p.name).toList(),
      'statuses': statuses.map((s) => s.name).toList(),
      'sortOption': sortOption.name,
    };
  }

  factory TaskFilterState.fromJson(Map<String, dynamic> json) {
    return TaskFilterState(
      category: json['category'] as String?,
      priorities: (json['priorities'] as List?)
              ?.map(
                (e) => TaskPriority.values.firstWhere(
                  (p) => p.name == e,
                  orElse: () => TaskPriority.medium,
                ),
              )
              .toSet() ??
          const {},
      statuses: (json['statuses'] as List?)
              ?.map(
                (e) => TaskStatusFilter.values.firstWhere(
                  (s) => s.name == e,
                  orElse: () => TaskStatusFilter.pending,
                ),
              )
              .toSet() ??
          const {},
      sortOption: TaskSortOption.values.firstWhere(
        (o) => o.name == json['sortOption'],
        orElse: () => TaskSortOption.dueDateAsc,
      ),
    );
  }
}
