import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

// The people, invite, join and code-compare screens are Core's shared ones
// (zt_sharing_ui), so every Zero-Trust app shows the same. Only what is
// about lists lives here.

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
}

String _listName(BuildContext context, String spaceId) {
  for (final x in ProviderScope.containerOf(context, listen: false).read(sharedListsProvider).lists) {
    if (x.shared!.spaceId == spaceId) return x.name;
  }
  return '';
}

/// The people screen of the shared list in [spaceId].
Future<void> openSharedList(BuildContext context, String spaceId, {bool inviteNow = false}) => ZtSpacePage.open(
  context,
  spaceId: spaceId,
  title: _listName(context, spaceId),
  description: context.l10n.sharedListE2e,
  inviteNow: inviteNow,
);

/// Joins a shared list from an invite link (pasted, scanned or opened).
Future<void> joinSharedList(BuildContext context, {String? initialLink}) =>
    ZtJoinSpacePage.open(context, initialLink: initialLink);

/// Turns the account's own [list] into a shared list: its tasks move into a
/// new shared space with this account as owner, then the invite page opens.
Future<void> shareList(BuildContext context, WidgetRef ref, TaskList list) async {
  final l = context.l10n;
  final manager = ref.read(taskManagerProvider);
  final tasks = manager.tasks.where((t) => (t.listId ?? TaskList.defaultId) == list.id).toList();
  final name = await ztAskSharingName(context, ref, title: l.shareListQ(list.name));
  if (name == null || !context.mounted) return;
  final controller = ref.read(sharedListsProvider.notifier);
  final lists = ref.read(taskListProvider);
  final String spaceId;
  try {
    spaceId = await controller.create(list, myName: name, tasks: tasks);
  } on Object {
    if (context.mounted) _snack(context, l.sharingNeedsInternet);
    return;
  }
  // The shared copy is saved; the account's own copy goes.
  await manager.dropPrivateCopies(tasks.map((t) => t.id));
  if (!list.isDefault) await lists.remove(list.id);
  if (!context.mounted) return;
  await openSharedList(context, spaceId, inviteNow: true);
}

/// A new, empty shared list.
Future<String?> newSharedList(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final listName = await showDialog<String>(context: context, builder: (_) => _ListNameDialog());
  if (listName == null || !context.mounted) return null;
  final name = await ztAskSharingName(context, ref, title: l.newSharedList);
  if (name == null || !context.mounted) return null;
  try {
    final spaceId = await ref.read(sharedListsProvider.notifier).create(TaskList.create(name: listName), myName: name);
    if (context.mounted) {
      await openSharedList(context, spaceId, inviteNow: true);
    }
    return TaskList.sharedId(spaceId);
  } on Object {
    if (context.mounted) _snack(context, l.sharingNeedsInternet);
    return null;
  }
}

class _ListNameDialog extends StatefulWidget {
  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.newSharedList),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: context.l10n.listName),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      TextButton(onPressed: _submit, child: Text(context.l10n.continueLabel)),
    ],
  );
}

/// Under the list chips: who a shared list is shared with, and people
/// waiting to join any list this account owns.
class SharedListStrip extends ConsumerWidget {
  const SharedListStrip({super.key, required this.scope});
  final TaskListScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(sharedListsProvider);
    if (state.lists.isEmpty) return const SizedBox.shrink();
    final joins = ref.watch(ztPendingJoinsProvider).value ?? const <PendingJoin>[];
    final spaceId = TaskList.spaceIdOf(scope.listId);
    TaskList? current;
    for (final x in state.lists) {
      if (x.shared!.spaceId == spaceId) current = x;
    }
    String nameOf(String id) {
      for (final x in state.lists) {
        if (x.shared!.spaceId == id) return x.name;
      }
      return '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final j in joins)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_add_alt),
              title: Text(l.joinRequestFor(j.name, nameOf(j.spaceId))),
              subtitle: Text(l.joinRequestHint),
              onTap: () => ztConfirmJoin(context, ref, j, title: nameOf(j.spaceId)),
            ),
          ),
        if (current != null)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
            leading: const Icon(Icons.group_outlined),
            title: Text(
              current.shared!.waiting
                  ? l.waitingToJoin
                  : l.sharedWith(current.shared!.members.map((m) => m.name).join(', ')),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openSharedList(context, spaceId!),
          ),
      ],
    );
  }
}
