import 'package:zero_trust_tasks/models/task_filter_state.dart';

/// A named, persisted snapshot of a [TaskFilterState] (item 28).
class SmartFilter {
  const SmartFilter({
    required this.id,
    required this.name,
    required this.filter,
  });

  final String id;
  final String name;
  final TaskFilterState filter;

  factory SmartFilter.fromJson(Map<String, dynamic> json) {
    return SmartFilter(
      id: json['id'] as String,
      name: json['name'] as String,
      filter: TaskFilterState.fromJson(json['filter'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filter': filter.toJson(),
  };
}
