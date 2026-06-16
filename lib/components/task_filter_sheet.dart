import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/task_filter_state.dart';
import 'package:zero_trust_tasks/models/task_sort_option.dart';
import 'package:zero_trust_tasks/models/task_status_filter.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

/// Bottom sheet for adjusting category/priority/status filters and the
/// sort order (item 1). Returns the new [TaskFilterState] when applied.
class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({
    super.key,
    required this.filterState,
    required this.categories,
  });

  final TaskFilterState filterState;
  final List<String> categories;

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late TaskFilterState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.filterState;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & sort',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _state = _state.clearFilters();
                      });
                    },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Status',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskStatusFilter.values.map((status) {
                  final selected = _state.statuses.contains(status);
                  return FilterChip(
                    label: Text(status.displayName),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        final statuses = Set<TaskStatusFilter>.of(
                          _state.statuses,
                        );
                        if (value) {
                          statuses.add(status);
                        } else {
                          statuses.remove(status);
                        }
                        _state = _state.copyWith(statuses: statuses);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Priority',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskPriority.values.map((priority) {
                  final selected = _state.priorities.contains(priority);
                  return FilterChip(
                    avatar: Icon(
                      priority.icon,
                      size: 16,
                      color: selected ? null : priority.getColor(context),
                    ),
                    label: Text(priority.displayName),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        final priorities = Set<TaskPriority>.of(
                          _state.priorities,
                        );
                        if (value) {
                          priorities.add(priority);
                        } else {
                          priorities.remove(priority);
                        }
                        _state = _state.copyWith(priorities: priorities);
                      });
                    },
                  );
                }).toList(),
              ),
              if (widget.categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.categories.map((category) {
                    final selected = _state.category == category;
                    return FilterChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          _state = _state.copyWith(
                            category: value ? category : null,
                            clearCategory: !value,
                          );
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TaskSortOption>(
                initialValue: _state.sortOption,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: TaskSortOption.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _state = _state.copyWith(sortOption: value);
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, _state),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
