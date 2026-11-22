import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// What is offered to ZT Keyboard: without a [query], every open task
/// (not done, archived or in the trash), the soonest due first and tasks
/// without a date after them. With a [query], every task that isn't
/// archived or in the trash whose title, description, notes, tags or
/// checklist hold it, open ones first.
List<Task> pickTasks(List<Task> tasks, String query) {
  final q = query.trim().toLowerCase();
  bool matches(Task t) =>
      t.title.toLowerCase().contains(q) ||
      (t.description ?? '').toLowerCase().contains(q) ||
      (t.notes ?? '').toLowerCase().contains(q) ||
      t.tags.any((tag) => tag.toLowerCase().contains(q)) ||
      t.subTasks.any((s) => s.title.toLowerCase().contains(q));
  final out = [
    for (final t in tasks)
      if (t.deletedAt == null && !t.isArchived && (q.isEmpty ? !t.isCompleted : matches(t))) t,
  ];
  out.sort((a, b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if ((ad == null) != (bd == null)) return ad == null ? 1 : -1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return out;
}

/// "Tuesday, November 24, 2026", with the time when one is set.
String pickDue(DateTime due) {
  final day = DateFormat.yMMMMEEEEd().format(due);
  if (due.hour == 0 && due.minute == 0) return day;
  return '$day, ${DateFormat.Hm().format(due)}';
}

/// The texts one task can hand to the keyboard: (icon, what it is, text).
/// The checklist is the task's title and each step on its own line, as a
/// list a message can show.
List<(IconData, String, String)> pickValues(Task task, AppL10n l10n) {
  final title = task.title.trim();
  final description = (task.description ?? '').trim();
  final notes = (task.notes ?? '').trim();
  final steps = [
    for (final s in task.subTasks)
      if (s.title.trim().isNotEmpty) '${s.isCompleted ? '☑' : '☐'} ${s.title.trim()}',
  ];
  return [
    if (title.isNotEmpty) (Icons.title, l10n.insertTaskTitle, title),
    if (task.dueDate != null) (Icons.event, l10n.insertTaskDue, pickDue(task.dueDate!)),
    if (task.dueDate != null && title.isNotEmpty)
      (Icons.event_note, l10n.insertTaskTitleAndDue, '$title, ${pickDue(task.dueDate!)}'),
    if (steps.isNotEmpty)
      (Icons.checklist, l10n.insertTaskChecklist, [if (title.isNotEmpty) title, ...steps].join('\n')),
    if (description.isNotEmpty) (Icons.notes, l10n.description, description),
    if (notes.isNotEmpty) (Icons.sticky_note_2_outlined, l10n.notes, notes),
    for (final link in task.links)
      if (link.trim().isNotEmpty) (Icons.link, l10n.insertTaskLink, link.trim()),
  ];
}

/// Opened by ZT Keyboard's "Insert from ZT apps" key, once the vault is
/// unlocked: the user taps a task and then what to type of it. Pops with
/// that text, or with nothing when the user goes back. Only the tapped text
/// leaves the app.
class PickForKeyboardPage extends ConsumerStatefulWidget {
  const PickForKeyboardPage({super.key});

  @override
  ConsumerState<PickForKeyboardPage> createState() => _PickForKeyboardPageState();
}

class _PickForKeyboardPageState extends ConsumerState<PickForKeyboardPage> {
  String _query = '';

  void _send(String text) => Navigator.of(context).pop(text);

  Future<void> _open(Task task) async {
    final values = pickValues(task, context.l10n);
    if (values.isEmpty) return;
    if (values.length == 1) return _send(values.single.$3);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (icon, label, text) in values)
                ListTile(
                  leading: Icon(icon),
                  title: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
                  subtitle: Text(label),
                  onTap: () => Navigator.of(sheet).pop(text),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _send(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manager = ref.watch(taskManagerProvider);
    final found = pickTasks(manager.tasks, _query);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.insertIntoKeyboard)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.insertSearchTasks,
                helperText: l10n.insertPickTaskHint,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (found.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _query.trim().isEmpty ? l10n.insertNoOpenTasks : l10n.insertNoTasksFound,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final t in found)
            ListTile(
              leading: Icon(t.isCompleted ? Icons.check_circle_outline : Icons.radio_button_unchecked),
              title: Text(
                t.title.trim().isEmpty ? l10n.insertUntitledTask : t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: t.dueDate == null
                  ? null
                  : Text(pickDue(t.dueDate!), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _open(t),
            ),
        ],
      ),
    );
  }
}
