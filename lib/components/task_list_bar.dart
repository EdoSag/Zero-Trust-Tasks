import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/components/task_list_dialogs.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/sharing/shared_list_pages.dart';

/// The row of lists above the tasks: Starred, All, each list, and New list.
/// Long-press a list to rename, recolour or delete it.
class TaskListBar extends ConsumerWidget {
  const TaskListBar({super.key, required this.scope, required this.onChanged});

  final TaskListScope scope;
  final ValueChanged<TaskListScope> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(taskListProvider);
    final lists = provider.lists;
    final tasks = ref.watch(taskManagerProvider).tasks;
    final open = tasks.where((t) => t.deletedAt == null && !t.isArchived && !t.isCompleted);
    int countFor(TaskList l) => open.where((t) => provider.byId(t.listId).id == l.id).length;
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
        padding: const EdgeInsetsDirectional.only(end: 8),
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
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
        children: [
          chip(
            label: starred == 0 ? context.l10n.starred : context.l10n.starredCount(starred),
            value: const TaskListScope.starred(),
            avatar: Icon(Icons.star, size: 18, color: Colors.amber.shade700),
          ),
          chip(label: context.l10n.allLists, value: const TaskListScope.all()),
          for (final list in lists)
            chip(
              label: list.shared?.waiting == true
                  ? context.l10n.waitingToJoin
                  : '${list.name} ${countFor(list)}',
              value: TaskListScope.list(list.id),
              avatar: list.isShared
                  ? Icon(Icons.group, size: 16, color: list.colorValue ?? scheme.primary)
                  : Icon(Icons.circle, size: 12, color: list.colorValue ?? scheme.primary),
              onLongPress: () => TaskListDialogs.showOptions(
                context,
                list,
                onDeleted: () {
                  if (scope.listId == list.id) onChanged(const TaskListScope.all());
                },
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.newList),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final id = await TaskListDialogs.newList(context, ref);
                if (id != null) onChanged(TaskListScope.list(id));
              },
            ),
          ),
          if (ref.watch(sharedListsProvider.select((s) => s.available)))
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                avatar: const Icon(Icons.group_add_outlined, size: 18),
                label: Text(context.l10n.joinListChip),
                tooltip: context.l10n.joinSharedList,
                visualDensity: VisualDensity.compact,
                onPressed: () => joinSharedList(context),
              ),
            ),
        ],
      ),
    );
  }
}
