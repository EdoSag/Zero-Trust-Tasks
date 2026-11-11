import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/sharing/shared_list_pages.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';

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

  /// "New list": a list of the account's own, or (when sharing works) a
  /// new shared list. Returns the new list's id.
  static Future<String?> newList(BuildContext context, WidgetRef ref) async {
    if (!ref.read(sharedListsProvider).available) return (await edit(context))?.id;
    final shared = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(context.l10n.newList),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: Text(context.l10n.newSharedList),
              subtitle: Text(context.l10n.sharedListE2e),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (shared == null || !context.mounted) return null;
    if (!shared) return (await edit(context))?.id;
    return newSharedList(context, ref);
  }

  /// Picks a list (or makes a new one). Returns its id, or null if cancelled.
  static Future<String?> pick(BuildContext context, {String? currentId, String? title}) {
    // A list still waiting for its owner can't take tasks yet.
    final lists = context.taskLists.lists.where((l) => l.shared?.waiting != true).toList();
    final current = currentId ?? TaskList.defaultId;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Text(title ?? context.l10n.moveToList, style: Theme.of(sheetContext).textTheme.titleMedium),
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
              title: Text(context.l10n.newList),
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

  /// Rename, recolour or delete [list]; share it, or manage a shared one.
  static Future<void> showOptions(BuildContext context, TaskList list, {VoidCallback? onDeleted}) {
    if (list.isShared) return _sharedOptions(context, list, onDeleted: onDeleted);
    final canShare = ProviderScope.containerOf(context, listen: false).read(sharedListsProvider).available;
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
              title: Text(context.l10n.renameOrChangeColour),
              onTap: () async {
                Navigator.pop(sheetContext);
                await edit(context, existing: list);
              },
            ),
            if (canShare && !list.isDefault)
              Consumer(
                builder: (_, ref, _) => ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(context.l10n.shareList),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await shareList(context, ref, list);
                  },
                ),
              ),
            if (!list.isDefault)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(sheetContext).colorScheme.error),
                title: Text(context.l10n.deleteList, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _delete(context, list);
                  onDeleted?.call();
                },
              )
            else
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text(context.l10n.theDefaultListCantBe),
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _sharedOptions(BuildContext context, TaskList list, {VoidCallback? onDeleted}) {
    final info = list.shared!;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(info.waiting ? context.l10n.waitingToJoin : list.name,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(context.l10n.sharedListOptions),
              onTap: () async {
                Navigator.pop(sheetContext);
                await openSharedList(context, info.spaceId);
                if (context.mounted && !context.taskLists.lists.any((l) => l.id == list.id)) onDeleted?.call();
              },
            ),
            if (!info.waiting)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.renameOrChangeColour),
                subtitle: info.isAdmin ? null : Text(context.l10n.onlyOwnersRename),
                enabled: info.isAdmin,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await edit(context, existing: list);
                },
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
        title: Text(context.l10n.deleteListQ(list.name)),
        content: Text(count == 0
            ? context.l10n.theListIsEmpty
            : context.l10n.listTasksToTrash(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.delete)),
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
                child: Text(context.l10n.makeASubtaskOf, style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              Expanded(
                child: candidates.isEmpty
                    ? Center(child: Text(context.l10n.noOtherOpenTasks))
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
      title: Text(widget.existing == null ? context.l10n.newList : context.l10n.editList),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.listName),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
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
      label: color == null ? context.l10n.defaultColour : context.l10n.colour,
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
