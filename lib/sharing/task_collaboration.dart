import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';
import 'package:zero_trust_tasks/sharing/task_comments.dart';

/// The members of [task]'s shared list who are still in it.
List<SpaceMember> membersOf(WidgetRef ref, Task task) {
  final list = ref.watch(taskListProvider).byId(task.listId);
  return [
    for (final m in list.shared?.members ?? const <SpaceMember>[])
      if (m.removedAtEpoch == null) m,
  ];
}

/// A member's name, "You" for this account, "?" when unknown.
String memberName(BuildContext context, List<SpaceMember> members, String userId, String me) {
  if (userId == me) return context.l10n.you;
  for (final m in members) {
    if (m.userId == userId) return m.name.isEmpty ? '?' : m.name;
  }
  return '?';
}

/// The assignee's name on a task card ("Dana"), for shared lists.
class AssigneeChip extends ConsumerWidget {
  const AssigneeChip({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = task.assigneeId;
    if (id == null) return const SizedBox.shrink();
    final me = ref.watch(sharedListsProvider.notifier).myUserId;
    final name = memberName(context, membersOf(ref, task), id, me);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${context.l10n.assignedTo} $name',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: id == me ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 12),
            const SizedBox(width: 4),
            Text(name, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// "Assigned to" on a task of a shared list: anyone in the list, or nobody.
/// The person it's assigned to gets a notification on their phone.
class AssigneeTile extends ConsumerWidget {
  const AssigneeTile({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(sharedListsProvider.notifier).myUserId;
    final members = membersOf(ref, task);
    final assignee = task.assigneeId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(l10n.assignedTo),
      subtitle: Text(assignee == null ? l10n.nobody : memberName(context, members, assignee, me)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text(l10n.nobody),
                  selected: assignee == null,
                  onTap: () => Navigator.of(sheet).pop(''),
                ),
                for (final m in members)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(memberName(context, members, m.userId, me)),
                    selected: assignee == m.userId,
                    onTap: () => Navigator.of(sheet).pop(m.userId),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) return;
        final userId = picked.isEmpty ? null : picked;
        if (userId == assignee) return;
        await ref.read(taskManagerProvider).updateTask(task.assignedTo(userId, by: me));
      },
    );
  }
}

/// Comments on a task of a shared list: everyone in the list reads and
/// adds them; each person can delete their own.
class TaskCommentsSection extends ConsumerStatefulWidget {
  const TaskCommentsSection({super.key, required this.task});
  final Task task;

  @override
  ConsumerState<TaskCommentsSection> createState() => _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends ConsumerState<TaskCommentsSection> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(sharedListsProvider.notifier).addComment(widget.task, text);
      _text.clear();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ztErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final comments = ref.watch(sharedListsProvider).comments[widget.task.id] ?? const <TaskComment>[];
    final me = ref.watch(sharedListsProvider.notifier).myUserId;
    final members = membersOf(ref, widget.task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.comments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.noCommentsYet, style: theme.textTheme.bodySmall),
          ),
        for (final c in comments)
          Card(
            child: ListTile(
              title: Text(c.text),
              subtitle: Text(
                '${memberName(context, members, c.by, me)} · ${DateFormat.MMMd().add_Hm().format(c.at)}',
              ),
              trailing: c.by == me
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteComment,
                      onPressed: () => ref.read(sharedListsProvider.notifier).deleteComment(widget.task, c),
                    )
                  : null,
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          minLines: 1,
          maxLines: 4,
          maxLength: TaskComment.maxLength,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: l10n.addAComment,
            counterText: '',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              tooltip: l10n.send,
              onPressed: _sending ? null : _send,
            ),
          ),
        ),
      ],
    );
  }
}
