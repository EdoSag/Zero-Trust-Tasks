import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/core/services/task_filter_service.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Writes what the Android home-screen widgets show
/// (`TaskListWidgetProvider.kt`, `QuickAddTaskWidgetProvider.kt`).
///
/// Each task widget shows one scope, picked when it is placed (W6): all
/// lists, Today, Starred or one list. The app writes every scope at once
/// (`tasks_widget_scopes`), so a widget shows its pick straight away.
///
/// The widgets live outside the vault, so whatever is written here is
/// stored unencrypted on the phone. By default that is only counts ("4 open
/// · 1 due today"). Task titles, due dates and list names are written
/// only when the user turns on "Show details on the home screen", and
/// are removed again when it is turned off or the account signs out.
class HomeWidgetService {
  const HomeWidgetService();

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const providerName = 'dev.sagron.zerotrusttasks.widgets.TaskListWidgetProvider';
  static const quickAddProviderName = 'dev.sagron.zerotrusttasks.widgets.QuickAddTaskWidgetProvider';
  static const maxRows = 5;

  /// Lists beyond this many get no scope of their own (picker and content).
  static const maxListScopes = 30;

  /// The scope key of a widget showing [filter] (and [list] for
  /// [WidgetFilter.list]; null is all lists), as `TaskListWidgetProvider`
  /// stores it per widget.
  static String scopeKey(WidgetFilter filter, [String? listId]) => switch (filter) {
        WidgetFilter.today => 'today',
        WidgetFilter.starred => 'starred',
        WidgetFilter.list => listId == null ? 'all' : 'list:$listId',
      };

  /// What every scope shows, keyed by [scopeKey]: all lists, Today,
  /// Starred and each list. [defaultListId] is what widgets placed before
  /// widgets had their own pick show (the old "Widget shows" setting).
  static Map<String, WidgetContent> scopesFor({
    required List<Task> tasks,
    required List<TaskList> lists,
    required bool showTasks,
    DateTime? now,
    String Function(String? listId)? resolveList,
  }) {
    WidgetContent content(WidgetFilter filter, TaskList? list) => contentFor(
          tasks: tasks,
          list: list,
          showTasks: showTasks,
          now: now,
          resolveList: resolveList,
          filter: filter,
        );
    return {
      scopeKey(WidgetFilter.list): content(WidgetFilter.list, null),
      scopeKey(WidgetFilter.today): content(WidgetFilter.today, null),
      scopeKey(WidgetFilter.starred): content(WidgetFilter.starred, null),
      for (final list in lists.take(maxListScopes)) scopeKey(WidgetFilter.list, list.id): content(WidgetFilter.list, list),
    };
  }

  /// The day [writeScopes] wrote for, as `TaskListWidgetProvider` compares it.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Writes every scope, the list names for the widget's list picker (only
  /// with details on) and the scope of widgets placed before the picker.
  Future<void> writeScopes({
    required Map<String, WidgetContent> scopes,
    required List<TaskList> lists,
    required bool showTasks,
    String? defaultListId,
    Map<String, WidgetContent>? scopesTomorrow,
    DateTime? day,
  }) async {
    if (!isSupported) return;
    String encode(Map<String, WidgetContent> s) =>
        jsonEncode({for (final MapEntry(:key, :value) in s.entries) key: value.toJson()});
    try {
      await HomeWidget.saveWidgetData<bool>('tasks_widget_locked', false);
      await HomeWidget.saveWidgetData<String>('tasks_widget_scopes', encode(scopes));
      await HomeWidget.saveWidgetData<String>(
        'tasks_widget_scopes_next',
        scopesTomorrow == null ? null : encode(scopesTomorrow),
      );
      await HomeWidget.saveWidgetData<String>('tasks_widget_day', day == null ? null : dayKey(day));
      await HomeWidget.saveWidgetData<String>(
        'tasks_widget_default_scope',
        scopeKey(WidgetFilter.list, defaultListId),
      );
      await HomeWidget.saveWidgetData<String>(
        'tasks_widget_lists',
        showTasks
            ? jsonEncode([
                for (final list in lists.take(maxListScopes)) {'id': list.id, 'name': list.name},
              ])
            : null,
      );
      await _clearOldRows();
      await _saveTexts();
      await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
      await HomeWidget.updateWidget(qualifiedAndroidName: quickAddProviderName);
    } on Object catch (e) {
      debugPrint('Home-screen widget not updated: $e');
    }
  }

  /// Before W6 one set of rows was written for every widget. Their titles
  /// must not outlive "Show details" being turned off.
  Future<void> _clearOldRows() async {
    if (await HomeWidget.getWidgetData<int>('tasks_widget_count') == null) return;
    await HomeWidget.saveWidgetData<int>('tasks_widget_count', null);
    await HomeWidget.saveWidgetData<String>('tasks_widget_title', null);
    await HomeWidget.saveWidgetData<String>('tasks_widget_summary', null);
    for (var i = 0; i < maxRows; i++) {
      await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_id', null);
      await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_title', null);
      await HomeWidget.saveWidgetData<String>('tasks_widget_row_${i}_due', null);
    }
  }

  /// What the widget would show, without writing it (also used by tests).
  static WidgetContent contentFor({
    required List<Task> tasks,
    required TaskList? list,
    required bool showTasks,
    DateTime? now,
    String Function(String? listId)? resolveList,
    WidgetFilter filter = WidgetFilter.list,
  }) {
    // Tasks whose list is gone belong to the default list.
    final listOf = resolveList ?? (String? id) => id ?? TaskList.defaultId;
    final today = now ?? DateTime.now();
    final open = tasks.where((t) => t.deletedAt == null && !t.isArchived && !t.isCompleted).toList();
    bool isToday(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
    final endOfToday = DateTime(today.year, today.month, today.day + 1);
    final inScope = switch (filter) {
      // Due today, or overdue and still open.
      WidgetFilter.today => open.where((t) => t.dueDate != null && t.dueDate!.isBefore(endOfToday)).toList(),
      WidgetFilter.starred => open.where((t) => t.starred).toList(),
      WidgetFilter.list when list != null => open.where((t) => listOf(t.listId) == list.id).toList(),
      WidgetFilter.list => open,
    };
    final dueToday = open.where((t) => t.dueDate != null && isToday(t.dueDate!)).length;
    // Against [today], not the clock: tomorrow's scopes are worked out ahead.
    final overdue = open.where((t) => t.dueDate != null && today.isAfter(t.dueDate!) && !isToday(t.dueDate!)).length;
    // With details off a list's widget counts every list (its name is
    // hidden, so a count of one list would be a puzzle); Today and Starred
    // count their own tasks.
    final scoped = showTasks || filter != WidgetFilter.list ? inScope.length : open.length;
    final parts = [
      scoped == 0 ? currentL10n.nothingToDo : currentL10n.nOpen(scoped),
      if (dueToday > 0) currentL10n.nDueToday(dueToday),
      if (overdue > 0) currentL10n.nOverdue(overdue),
    ];
    final genericTitle = switch (filter) {
      WidgetFilter.today => currentL10n.today,
      WidgetFilter.starred => currentL10n.starred,
      WidgetFilter.list => currentL10n.allTasks2,
    };
    if (!showTasks) {
      return WidgetContent(title: genericTitle, summary: parts.join(' · '), rows: const []);
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
      if (isToday(d)) return currentL10n.today;
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) return currentL10n.tomorrow;
      final label = DateFormat('EEE d MMM').format(d);
      return d.isBefore(today) ? currentL10n.overdueLabel(label) : label;
    }

    return WidgetContent(
      title: filter == WidgetFilter.list ? list?.name ?? currentL10n.allLists : genericTitle,
      summary: parts.join(' · '),
      rows: [
        for (final t in inScope.take(maxRows)) WidgetRow(id: t.id, title: t.title, due: dueLabel(t)),
      ],
    );
  }

  /// Signed out: every task widget shows a lock, and no counts, titles or
  /// list names stay on the phone.
  Future<void> clear() async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<bool>('tasks_widget_locked', true);
      await HomeWidget.saveWidgetData<String>('tasks_widget_scopes', null);
      await HomeWidget.saveWidgetData<String>('tasks_widget_scopes_next', null);
      await HomeWidget.saveWidgetData<String>('tasks_widget_day', null);
      await HomeWidget.saveWidgetData<String>('tasks_widget_lists', null);
      await _clearOldRows();
      await _saveTexts();
      await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
    } on Object catch (e) {
      debugPrint('Home-screen widget not cleared: $e');
    }
  }

  /// The widgets' fixed texts, in the app's language (WidgetText.kt).
  Future<void> _saveTexts() async {
    final l = currentL10n;
    final texts = {
      'add_task': l.widgetAddTask,
      'complete_task': l.widgetCompleteTask,
      'open_to_see': l.widgetOpenToSee,
      'your_tasks': l.yourTasks,
      'open_app_summary': l.widgetOpenAppSummary,
      'done_saved': l.widgetDoneSaved,
      'signed_out': l.signedOut,
      'all_lists': l.allLists,
      'today': l.today,
      'starred': l.starred,
      'pick_title': l.widgetShows,
      'pick_hint': l.widgetPickListHint,
      'cancel': l.cancel,
    };
    for (final MapEntry(:key, :value) in texts.entries) {
      await HomeWidget.saveWidgetData<String>('tasks_widget_text_$key', value);
    }
  }
}

/// Which tasks a widget shows: one list (or all), those due today, or the
/// starred ones.
enum WidgetFilter { list, today, starred }

class WidgetContent {
  const WidgetContent({required this.title, required this.summary, required this.rows, this.locked = false});
  final String title;
  final String summary;
  final List<WidgetRow> rows;

  /// Signed out: the widget shows a lock instead of rows.
  final bool locked;

  /// As `TaskListWidgetProvider` reads it: t title, s summary, r rows.
  Map<String, Object> toJson() => {
        't': title,
        's': summary,
        'r': [
          for (final row in rows) {'id': row.id, 't': row.title, if (row.due != null) 'd': row.due!},
        ],
      };
}

class WidgetRow {
  const WidgetRow({required this.id, required this.title, this.due});
  final String id;
  final String title;
  final String? due;
}
