import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/core/services/quick_add_parser.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// One line to add a task: "call mum tomorrow 6pm". Dates, times, repeats,
/// `!priority` and `#tags` are read as you type (English and Hebrew) and
/// shown as chips before saving. "More" opens the full editor with
/// everything filled in.
Future<void> showQuickAdd(BuildContext context, {String? listId, bool starred = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickAddSheet(listId: listId, starred: starred),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, this.listId, this.starred = false});

  final String? listId;
  final bool starred;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _controller = TextEditingController();

  /// Off: the text is saved exactly as typed, with no date read from it.
  bool _readDates = true;
  bool _saving = false;
  late bool _starred = widget.starred;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuickAdd get _parsed => _readDates
      ? QuickAddParser.parse(_controller.text)
      : QuickAdd(title: _controller.text.trim());

  Task _build(QuickAdd parsed) => Task.create(
        title: parsed.title,
        dueDate: parsed.due,
        // A time of day is a reminder; a bare date isn't.
        reminderAt: parsed.hasTime ? parsed.due : null,
        recurrence: parsed.recurrence,
        priority: parsed.priority ?? TaskPriority.medium,
        tags: parsed.tags,
        listId: widget.listId,
        starred: _starred,
      );

  Future<void> _save() async {
    final parsed = _parsed;
    if (parsed.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.taskManager.addTask(_build(parsed));
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        // Short, so it's out of the way when adding several in a row.
        duration: const Duration(seconds: 2),
        content: Text(parsed.due == null
            ? currentL10n.taskAdded
            : currentL10n.taskAddedDue(describeDue(parsed.due!, parsed.hasTime))),
      ));
    } on Object catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(currentL10n.cantAddTask('$e'))));
    }
  }

  void _more() {
    final parsed = _parsed;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => AddTaskScreen(
        draft: parsed.isEmpty ? null : _build(parsed),
        initialListId: widget.listId,
        initialStarred: _starred,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final theme = Theme.of(context);
    final found = _readDates &&
        (parsed.due != null || parsed.recurrence != null || parsed.priority != null || parsed.tags.isNotEmpty);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.l10n.newTask,
              hintText: context.l10n.callMumTomorrow6pm,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          if (found)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (parsed.due != null)
                  Chip(
                    avatar: Icon(parsed.hasTime ? Icons.alarm : Icons.event, size: 18),
                    label: Text(describeDue(parsed.due!, parsed.hasTime)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (parsed.recurrence != null)
                  Chip(
                    avatar: const Icon(Icons.repeat, size: 18),
                    label: Text(_describeRepeat(parsed.recurrence!)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (parsed.priority != null)
                  Chip(
                    avatar: Icon(parsed.priority!.icon, size: 18),
                    label: Text(parsed.priority!.displayName),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final tag in parsed.tags)
                  Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
                TextButton(
                  onPressed: () => setState(() => _readDates = false),
                  child: Text(context.l10n.keepAsTyped),
                ),
              ],
            )
          else if (!_readDates)
            Row(
              children: [
                Expanded(
                  child: Text(context.l10n.savedExactlyAsTyped, style: theme.textTheme.bodySmall),
                ),
                TextButton(
                  onPressed: () => setState(() => _readDates = true),
                  child: Text(context.l10n.readDates),
                ),
              ],
            )
          else
            Text(
              context.l10n.quickAddHelp,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (found && parsed.title != _controller.text.trim())
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(context.l10n.titleIs(parsed.title), style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(_starred ? Icons.star : Icons.star_border, color: _starred ? Colors.amber.shade700 : null),
                tooltip: _starred ? context.l10n.removeStar : context.l10n.star,
                onPressed: () => setState(() => _starred = !_starred),
              ),
              Expanded(
                child: Text(
                  context.l10n.listIs(context.taskLists.byId(widget.listId).name),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: _more, child: Text(context.l10n.moreOptions)),
              const SizedBox(width: 8),
              FilledButton(
                // The app theme makes filled buttons full width; not in a row.
                style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                onPressed: parsed.isEmpty || _saving ? null : _save,
                child: Text(context.l10n.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _describeRepeat(RecurrenceRule rule) {
    if (rule.interval <= 1) return rule.frequency.displayName;
    final l = currentL10n;
    return switch (rule.frequency) {
      RecurrenceFrequency.daily => l.everyNDays(rule.interval),
      RecurrenceFrequency.weekly => l.everyNWeeks(rule.interval),
      RecurrenceFrequency.monthly => l.everyNMonths(rule.interval),
      RecurrenceFrequency.yearly => l.everyNYears(rule.interval),
    };
  }
}

/// "Today", "Tomorrow 18:00", "Fri 13 Nov", "12 May 2027 14:00".
String describeDue(DateTime due, bool hasTime, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inHours / 24;
  final day = switch (days.round()) {
    0 => currentL10n.today,
    1 => currentL10n.tomorrow,
    _ => DateFormat(due.year == clock.year ? 'EEE d MMM' : 'd MMM y').format(due),
  };
  return hasTime ? '$day ${DateFormat('HH:mm').format(due)}' : day;
}
