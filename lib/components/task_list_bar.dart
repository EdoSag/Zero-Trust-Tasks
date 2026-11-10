import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/components/task_list_dialogs.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// The row of lists above the tasks: Starred, All, each list, and New list.
/// Long-press a list to rename, recolour or delete it.
class TaskListBar extends ConsumerWidget {
  const TaskListBar({super.key, required this.scope, required this.onChanged});

  final TaskListScope scope;
  final ValueChanged<TaskListScope> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(taskListProvider).lists;
    final tasks = ref.watch(taskManagerProvider).tasks;
    final open = tasks.where((t) => t.deletedAt == null && !t.isArchived && !t.isCompleted);
    int countFor(TaskList l) => open.where((t) => (t.listId ?? TaskList.defaultId) == l.id).length;
    final starred = open.where((t) => t.starred).length;
    final scheme = Theme.of(context).colorScheme;

    Widget chip({
      required String label,
      required TaskListScope value,
      Widget? avatar,
      VoidCallback? onLongPress,
    }) {
      final selected = scope == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ChoiceChip(
            avatar: avatar,
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(value),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        children: [
          chip(
            label: starred == 0 ? 'Starred' : 'Starred $starred',
            value: const TaskListScope.starred(),
            avatar: Icon(Icons.star, size: 18, color: Colors.amber.shade700),
          ),
          chip(label: 'All lists', value: const TaskListScope.all()),
          for (final list in lists)
            chip(
              label: '${list.name} ${countFor(list)}',
              value: TaskListScope.list(list.id),
              avatar: Icon(Icons.circle, size: 12, color: list.colorValue ?? scheme.primary),
              onLongPress: () => TaskListDialogs.showOptions(
                context,
                list,
                onDeleted: () {
                  if (scope.listId == list.id) onChanged(const TaskListScope.all());
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('New list'),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final created = await TaskListDialogs.edit(context);
                if (created != null) onChanged(TaskListScope.list(created.id));
              },
            ),
          ),
        ],
      ),
    );
  }
}
