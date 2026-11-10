import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// Dialogs shared by the Tasks tab, task details and the editor for
/// creating, picking and managing task lists.
class TaskListDialogs {
  TaskListDialogs._();

  /// Name and colour for a new list, or for [existing]. Returns the saved
  /// list, or null if cancelled.
  static Future<TaskList?> edit(BuildContext context, {TaskList? existing}) async {
    final result = await showDialog<(String, int?)>(
      context: context,
      builder: (_) => _EditListDialog(existing: existing),
    );
    if (result == null || !context.mounted) return null;
    final (name, color) = result;
    final lists = context.taskLists;
    if (existing == null) return lists.create(name, color: color);
    // Renaming the default list stores it for the first time.
    final updated = existing.copyWith(name: name, color: color, clearColor: color == null);
    await lists.save(updated);
    return updated;
  }

  /// Picks a list (or makes a new one). Returns its id, or null if cancelled.
  static Future<String?> pick(BuildContext context, {String? currentId, String title = 'Move to list'}) {
    final lists = context.taskLists.lists;
    final current = currentId ?? TaskList.defaultId;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final list in lists)
              ListTile(
                leading: Icon(Icons.circle, color: list.colorValue ?? Theme.of(sheetContext).colorScheme.primary, size: 16),
                title: Text(list.name),
                trailing: list.id == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, list.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New list'),
              onTap: () async {
                final created = await edit(sheetContext);
                if (created != null && sheetContext.mounted) Navigator.pop(sheetContext, created.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Rename, recolour or delete [list].
  static Future<void> showOptions(BuildContext context, TaskList list, {VoidCallback? onDeleted}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(list.name, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename or change colour'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await edit(context, existing: list);
              },
            ),
            if (!list.isDefault)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(sheetContext).colorScheme.error),
                title: Text('Delete list', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _delete(context, list);
                  onDeleted?.call();
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('The default list can\'t be deleted'),
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _delete(BuildContext context, TaskList list) async {
    final manager = context.taskManager;
    final count = manager.tasks
        .where((t) => t.deletedAt == null && (t.listId ?? TaskList.defaultId) == list.id)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${list.name}"?'),
        content: Text(count == 0
            ? 'The list is empty.'
            : 'Its $count ${count == 1 ? 'task goes' : 'tasks go'} to Trash, where '
                '${count == 1 ? 'it stays' : 'they stay'} for 30 days.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final lists = context.taskLists;
    await manager.trashList(list.id);
    await lists.remove(list.id);
  }

  /// Picks the task that [task] becomes a subtask of (same list first).
  static Future<Task?> pickParent(BuildContext context, Task task) {
    final candidates = context.taskManager.tasks
        .where((t) => t.id != task.id && t.deletedAt == null && !t.isArchived && !t.isCompleted)
        .toList()
      ..sort((a, b) {
        final sameA = a.listId == task.listId ? 0 : 1;
        final sameB = b.listId == task.listId ? 0 : 1;
        if (sameA != sameB) return sameA - sameB;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return showModalBottomSheet<Task>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('Make a subtask of…', style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(child: Text('No other open tasks'))
                    : ListView(
                        children: [
                          for (final t in candidates)
                            ListTile(
                              title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(sheetContext.taskLists.byId(t.listId).name),
                              onTap: () => Navigator.pop(sheetContext, t),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditListDialog extends StatefulWidget {
  const _EditListDialog({this.existing});

  final TaskList? existing;

  @override
  State<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends State<_EditListDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late int? _color = widget.existing?.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _color));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New list' : 'Edit list'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'List name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Swatch(
                color: null,
                selected: _color == null,
                fill: scheme.primary,
                onTap: () => setState(() => _color = null),
              ),
              for (final c in TaskList.palette)
                _Swatch(color: c, selected: _color == c, fill: Color(c), onTap: () => setState(() => _color = c)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.fill, required this.onTap});

  final int? color;
  final bool selected;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: color == null ? 'Default colour' : 'Colour',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child: color == null ? Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.onPrimary) : null,
        ),
      ),
    );
  }
}
