import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// Writes what the Android home-screen widget shows
/// (`TaskListWidgetProvider.kt`).
///
/// The widget lives outside the vault, so whatever is written here is
/// stored unencrypted on the phone. By default that is only counts ("4 open
/// · 1 due today"). Task titles, due dates and the list name are written
/// only when the user turns on "Show tasks on the home-screen widget", and
/// are removed again when it is turned off or the account signs out.
class HomeWidgetService {
  const HomeWidgetService();

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const providerName = 'dev.sagron.zerotrusttasks.widgets.TaskListWidgetProvider';
  static const maxRows = 5;

  /// What the widget would show, without writing it (also used by tests).
  static WidgetContent contentFor({
    required List<Task> tasks,
    required TaskList? list,
    required bool showTasks,
    DateTime? now,
    String Function(String? listId)? resolveList,
  }) {
    // Tasks whose list is gone belong to the default list.
    final listOf = resolveList ?? (String? id) => id ?? TaskList.defaultId;
    final today = now ?? DateTime.now();
    final open = tasks.where((t) => t.deletedAt == null && !t.isArchived && !t.isCompleted).toList();
    final inScope = list == null
        ? open
        : open.where((t) => listOf(t.listId) == list.id).toList();
    bool isToday(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
    final dueToday = open.where((t) => t.dueDate != null && isToday(t.dueDate!)).length;
    final overdue = open.where((t) => t.isOverdue && !isToday(t.dueDate!)).length;
    final scoped = showTasks ? inScope.length : open.length;
    final parts = [
      scoped == 0 ? 'Nothing to do' : '$scoped open',
      if (dueToday > 0) '$dueToday due today',
      if (overdue > 0) '$overdue overdue',
    ];
    if (!showTasks) {
      return WidgetContent(title: 'ZT Tasks', summary: parts.join(' · '), rows: const []);
    }
    inScope.sort((a, b) {
      final ad = a.dueDate, bd = b.dueDate;
      if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
      if (ad != null && bd == null) return -1;
      if (ad == null && bd != null) return 1;
      if (a.starred != b.starred) return a.starred ? -1 : 1;
      return TaskFilterService.compareManual(a, b);
    });
    String? dueLabel(Task t) {
      final d = t.dueDate;
      if (d == null) return null;
      if (isToday(d)) return 'Today';
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) return 'Tomorrow';
      final label = DateFormat('EEE d MMM').format(d);
      return d.isBefore(today) ? 'Overdue · $label' : label;
    }

    return WidgetContent(
      title: list?.name ?? 'All lists',
      summary: parts.join(' · '),
      rows: [
        for (final t in inScope.take(maxRows)) WidgetRow(id: t.id, title: t.title, due: dueLabel(t)),
      ],
    );
  }

  Future<void> write(WidgetContent content) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>('tasks_widget_title', content.title);
      await HomeWidget.saveWidgetData<String>('tasks_widget_summary', content.summary);
      await HomeWidget.saveWidgetData<int>('tasks_widget_count', content.rows.length);
      for (var i = 0; i < maxRows; i++) {
        final row = i < content.rows.length ? content.rows[i] : null;
        await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_id', row?.id);
        await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_title', row?.title);
        await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_due', row?.due);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
    } on Object catch (e) {
      debugPrint('Home-screen widget not updated: $e');
    }
  }

  /// Back to the signed-out look: no counts, no titles.
  Future<void> clear() => write(const WidgetContent(
        title: 'ZT Tasks',
        summary: 'Open the app to see your tasks',
        rows: [],
      ));
}

class WidgetContent {
  const WidgetContent({required this.title, required this.summary, required this.rows});
  final String title;
  final String summary;
  final List<WidgetRow> rows;
}

class WidgetRow {
  const WidgetRow({required this.id, required this.title, this.due});
  final String id;
  final String title;
  final String? due;
}
