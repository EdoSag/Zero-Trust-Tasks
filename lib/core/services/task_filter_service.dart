import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_section.dart';
import 'package:zero_trust_tasks/models/task_sort_option.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';

/// Pure functions for searching, filtering, sorting and grouping tasks for
/// the tasks list page. Kept free of widgets/state so it's easy to reuse
/// (dashboard navigation, saved smart filters, etc).
class TaskFilterService {
  TaskFilterService._();

  /// Matches the query against title, description, category and
  /// sub-task titles (item 24 — search across all of these).
  static List<Task> searchTasks(List<Task> tasks, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return tasks;
    }
    return tasks.where((task) {
      if (task.title.toLowerCase().contains(trimmed)) {
        return true;
      }
      if (task.description?.toLowerCase().contains(trimmed) ?? false) {
        return true;
      }
      if (task.category?.toLowerCase().contains(trimmed) ?? false) {
        return true;
      }
      return task.subTasks.any(
        (subTask) => subTask.title.toLowerCase().contains(trimmed),
      );
    }).toList();
  }

  static bool _matchesStatus(Task task, TaskStatusFilter status) {
    switch (status) {
      case TaskStatusFilter.pending:
        return !task.isCompleted;
      case TaskStatusFilter.completed:
        return task.isCompleted;
      case TaskStatusFilter.overdue:
        return task.isOverdue;
      case TaskStatusFilter.today:
        return !task.isCompleted && _isDueOnDate(task, DateTime.now());
      case TaskStatusFilter.upcoming:
        return !task.isCompleted &&
            task.dueDate != null &&
            !task.isOverdue &&
            !_isDueOnDate(task, DateTime.now());
    }
  }

  static bool _isDueOnDate(Task task, DateTime date) {
    final due = task.dueDate;
    if (due == null) {
      return false;
    }
    return due.year == date.year &&
        due.month == date.month &&
        due.day == date.day;
  }

  static List<Task> applyFilters(List<Task> tasks, TaskFilterState filter) {
    var result = searchTasks(tasks, filter.searchQuery);
    if (filter.category != null) {
      result = result.where((t) => t.category == filter.category).toList();
    }
    if (filter.priorities.isNotEmpty) {
      result =
          result.where((t) => filter.priorities.contains(t.priority)).toList();
    }
    if (filter.statuses.isNotEmpty) {
      result = result
          .where(
            (t) => filter.statuses.any((status) => _matchesStatus(t, status)),
          )
          .toList();
    }
    return result;
  }

  static List<Task> sortTasks(List<Task> tasks, TaskSortOption sortOption) {
    final sorted = List<Task>.of(tasks);
    switch (sortOption) {
      case TaskSortOption.dueDateAsc:
        sorted.sort((a, b) => _compareDueDate(a, b, ascending: true));
      case TaskSortOption.dueDateDesc:
        sorted.sort((a, b) => _compareDueDate(a, b, ascending: false));
      case TaskSortOption.priority:
        sorted.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      case TaskSortOption.createdDate:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TaskSortOption.alphabetical:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return sorted;
  }

  static int _compareDueDate(Task a, Task b, {required bool ascending}) {
    if (a.dueDate == null && b.dueDate == null) {
      return 0;
    }
    if (a.dueDate == null) {
      return 1;
    }
    if (b.dueDate == null) {
      return -1;
    }
    return ascending
        ? a.dueDate!.compareTo(b.dueDate!)
        : b.dueDate!.compareTo(a.dueDate!);
  }

  /// Groups tasks into [TaskSection]s for the sectioned list view (item 12).
  static Map<TaskSection, List<Task>> groupBySection(List<Task> tasks) {
    final sections = <TaskSection, List<Task>>{
      TaskSection.overdue: [],
      TaskSection.today: [],
      TaskSection.upcoming: [],
      TaskSection.noDueDate: [],
      TaskSection.completed: [],
    };
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.isCompleted) {
        sections[TaskSection.completed]!.add(task);
      } else if (task.isOverdue) {
        sections[TaskSection.overdue]!.add(task);
      } else if (_isDueOnDate(task, now)) {
        sections[TaskSection.today]!.add(task);
      } else if (task.dueDate != null) {
        sections[TaskSection.upcoming]!.add(task);
      } else {
        sections[TaskSection.noDueDate]!.add(task);
      }
    }
    return sections;
  }
}
