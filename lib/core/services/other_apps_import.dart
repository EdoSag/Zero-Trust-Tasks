import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/task_priority.dart';

/// The apps whose exports [OtherAppsImporter] reads.
enum ImportSource { todoist, microsoftToDo, tickTick }

/// Why a file couldn't be read. The settings page words each one.
enum ImportProblem { notRecognised, empty }

class OtherAppsImportException implements Exception {
  const OtherAppsImportException(this.problem);
  final ImportProblem problem;
  @override
  String toString() => 'OtherAppsImportException(${problem.name})';
}

/// What an export turns into.
class OtherAppsImport {
  const OtherAppsImport({
    required this.source,
    required this.lists,
    required this.tasks,
    required this.skipped,
  });

  final ImportSource source;

  /// Lists to create. Lists whose name already exists here are not in it:
  /// their tasks go to the existing list ("Inbox", "Tasks" and "My Tasks"
  /// go to the default list).
  final List<TaskList> lists;
  final List<Task> tasks;

  /// Deleted, "won't do" or empty entries left out.
  final int skipped;
}

/// Reads tasks exported from Todoist, Microsoft To Do or TickTick, all on
/// the phone. The format is recognised from the file itself:
///
/// * Todoist: a project's CSV ("Export as a template", one file per
///   project, named after it) or the backup .zip of those CSVs. Indented
///   rows (INDENT 2 and deeper) become subtasks of the task above them;
///   sections become tags; comments are added to the description.
/// * Microsoft To Do: the JSON of lists and tasks that To Do exporters
///   write from Microsoft Graph (`displayName`, `tasks`, `checklistItems`).
/// * TickTick: the backup CSV (Settings, Account, Generate backup).
///   Checklist items and subtasks become subtasks.
///
/// Ids are derived from the source's own ids (or the list, title and row),
/// so importing the same file twice doesn't create duplicates. Nothing is
/// sent anywhere.
class OtherAppsImporter {
  const OtherAppsImporter();

  static const _uuid = Uuid();

  OtherAppsImport parse(
    Uint8List bytes, {
    String fileName = '',
    required List<TaskList> existingLists,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final lists = _Lists(existingLists, at);
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (isZip) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final csvs = [
        for (final f in archive.files)
          if (f.isFile && f.name.toLowerCase().endsWith('.csv')) f,
      ]..sort((a, b) => a.name.compareTo(b.name));
      final tasks = <Task>[];
      var skipped = 0;
      for (final f in csvs) {
        final rows = _Csv.parse(_text(f.content));
        if (_isTickTick(rows)) {
          final r = _tickTick(rows, lists, at);
          tasks.addAll(r.$1);
          skipped += r.$2;
        } else if (_isTodoist(rows)) {
          final r = _todoist(rows, _baseName(f.name), lists, at);
          tasks.addAll(r.$1);
          skipped += r.$2;
        }
      }
      if (csvs.isEmpty) throw const OtherAppsImportException(ImportProblem.notRecognised);
      final source = csvs.any((f) => _isTickTick(_Csv.parse(_text(f.content))))
          ? ImportSource.tickTick
          : ImportSource.todoist;
      return _done(source, lists, tasks, skipped);
    }
    final text = _text(bytes);
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final r = _microsoftToDo(trimmed, lists, at);
      return _done(ImportSource.microsoftToDo, lists, r.$1, r.$2);
    }
    final rows = _Csv.parse(text);
    if (_isTickTick(rows)) {
      final r = _tickTick(rows, lists, at);
      return _done(ImportSource.tickTick, lists, r.$1, r.$2);
    }
    if (_isTodoist(rows)) {
      final r = _todoist(rows, _baseName(fileName), lists, at);
      return _done(ImportSource.todoist, lists, r.$1, r.$2);
    }
    throw const OtherAppsImportException(ImportProblem.notRecognised);
  }

  OtherAppsImport _done(ImportSource source, _Lists lists, List<Task> tasks, int skipped) {
    if (tasks.isEmpty) throw const OtherAppsImportException(ImportProblem.empty);
    return OtherAppsImport(source: source, lists: lists.created, tasks: tasks, skipped: skipped);
  }

  static String _id(String kind, String key) => _uuid.v5(Namespace.url.value, 'import:$kind:$key');

  static String _text(List<int> bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    return text;
  }

  static String _baseName(String path) {
    var name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    // Todoist's backup names files "Project name [123456].csv".
    return name.replaceAll(RegExp(r'\s*\[\d+\]$'), '').trim();
  }

  // ---------------------------------------------------------------- Todoist

  static bool _isTodoist(List<List<String>> rows) {
    if (rows.isEmpty) return false;
    final head = rows.first.map((c) => c.trim().toUpperCase()).toList();
    return head.contains('TYPE') && head.contains('CONTENT');
  }

  (List<Task>, int) _todoist(List<List<String>> rows, String project, _Lists lists, DateTime now) {
    final head = rows.first.map((c) => c.trim().toUpperCase()).toList();
    String cell(List<String> row, String name) {
      final i = head.indexOf(name);
      return i < 0 || i >= row.length ? '' : row[i].trim();
    }

    final listId = lists.idFor(project.isEmpty ? null : project, 'todoist:$project');
    final tasks = <Task>[];
    var skipped = 0;
    String? section;
    // The task a deeper row belongs to, and the rows already used (ids).
    Task? parent;
    final seen = <String, int>{};
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      final type = cell(row, 'TYPE').toLowerCase();
      final content = cell(row, 'CONTENT');
      if (type == 'section') {
        section = content.isEmpty ? null : content;
        parent = null;
        continue;
      }
      if (type == 'note' || type == 'comment') {
        if (parent != null && content.isNotEmpty) {
          final i = tasks.indexOf(parent);
          final description = [if ((parent.description ?? '').isNotEmpty) parent.description!, content].join('\n\n');
          parent = parent.copyWith(description: description);
          tasks[i] = parent;
        }
        continue;
      }
      if (type != 'task') continue;
      if (content.isEmpty) {
        skipped++;
        continue;
      }
      final indent = int.tryParse(cell(row, 'INDENT')) ?? 1;
      if (indent > 1 && parent != null) {
        final i = tasks.indexOf(parent);
        final key = '$project|${parent.id}|$content';
        final n = seen[key] = (seen[key] ?? 0) + 1;
        parent = parent.copyWith(
          subTasks: [...parent.subTasks, SubTask(id: _id('sub', '$key|$n'), title: content)],
        );
        tasks[i] = parent;
        continue;
      }
      final key = 'todoist|$project|$content';
      final n = seen[key] = (seen[key] ?? 0) + 1;
      final description = cell(row, 'DESCRIPTION');
      final dateText = cell(row, 'DATE');
      final due = _parseDate(cell(row, 'DEADLINE')) ?? _parseDate(dateText);
      final unread = dateText.isNotEmpty && _parseDate(dateText) == null;
      final task = Task(
        id: _id('task', '$key|$n'),
        title: content,
        description: [
          if (description.isNotEmpty) description,
          // A date Todoist kept as typed ("every monday"): kept as text.
          if (unread) dateText,
        ].join('\n').ifEmptyNull,
        priority: switch (cell(row, 'PRIORITY')) {
          // Todoist's CSV: 1 is p1 (highest), 4 is p4 (no priority).
          '1' => TaskPriority.critical,
          '2' => TaskPriority.high,
          '3' => TaskPriority.medium,
          _ => TaskPriority.low,
        },
        dueDate: due,
        tags: [if (section != null) section],
        listId: listId,
        position: (tasks.length + 1) * 1024.0,
        createdAt: now,
        updatedAt: now,
      );
      tasks.add(task);
      parent = task;
    }
    return (tasks, skipped);
  }

  // -------------------------------------------------------- Microsoft To Do

  (List<Task>, int) _microsoftToDo(String text, _Lists lists, DateTime now) {
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const OtherAppsImportException(ImportProblem.notRecognised);
    }
    // {"lists": [...]}, {"value": [...]} (Graph's own paging) or a bare list.
    final rawLists = switch (json) {
      {'lists': final List l} => l,
      {'value': final List l} => l,
      {'taskLists': final List l} => l,
      final List l => l,
      _ => null,
    };
    if (rawLists == null || rawLists.isEmpty || rawLists.first is! Map || !(rawLists.first as Map).containsKey('displayName')) {
      throw const OtherAppsImportException(ImportProblem.notRecognised);
    }
    final tasks = <Task>[];
    var skipped = 0;
    for (final raw in rawLists) {
      if (raw is! Map) continue;
      final name = (raw['displayName'] as String?)?.trim();
      final key = raw['id'] as String? ?? name ?? 'list';
      final listId = raw['wellknownListName'] == 'defaultList' ? null : lists.idFor(name, 'todo:$key');
      var order = 0;
      for (final t in (raw['tasks'] as List? ?? const [])) {
        if (t is! Map) continue;
        final title = (t['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) {
          skipped++;
          continue;
        }
        order++;
        final done = t['status'] == 'completed';
        final created = _date(t['createdDateTime']) ?? now;
        final updated = _date(t['lastModifiedDateTime']) ?? created;
        final body = t['body'];
        final notes = body is Map ? (body['content'] as String?)?.trim() ?? '' : '';
        final isHtml = body is Map && body['contentType'] == 'html';
        tasks.add(Task(
          id: _id('task', 'todo:${t['id'] ?? '$key|$order|$title'}'),
          title: title,
          description: (isHtml ? _stripHtml(notes) : notes).ifEmptyNull,
          priority: t['importance'] == 'high' ? TaskPriority.high : TaskPriority.medium,
          dueDate: _graphDay(t['dueDateTime']),
          reminderAt: t['isReminderOn'] == true ? _graphTime(t['reminderDateTime']) : null,
          isCompleted: done,
          completedAt: done ? (_graphTime(t['completedDateTime']) ?? updated) : null,
          starred: t['importance'] == 'high',
          tags: [
            for (final c in (t['categories'] as List? ?? const []))
              if (c is String && c.trim().isNotEmpty) c.trim(),
          ],
          links: [
            for (final r in (t['linkedResources'] as List? ?? const []))
              if (r is Map && r['webUrl'] is String) r['webUrl'] as String,
          ],
          subTasks: [
            for (final c in (t['checklistItems'] as List? ?? const []))
              if (c is Map && ((c['displayName'] as String?) ?? '').trim().isNotEmpty)
                SubTask(
                  id: _id('sub', 'todo:${c['id'] ?? '${t['id']}|${c['displayName']}'}'),
                  title: (c['displayName'] as String).trim(),
                  isCompleted: c['isChecked'] == true,
                ),
          ],
          listId: listId,
          position: order * 1024.0,
          createdAt: created,
          updatedAt: updated,
        ));
      }
    }
    return (tasks, skipped);
  }

  /// Graph's {dateTime, timeZone}: To Do stores due dates as midnight of
  /// the chosen day; keep the day.
  static DateTime? _graphDay(Object? value) {
    final t = value is Map ? DateTime.tryParse('${value['dateTime']}') : null;
    return t == null ? null : DateTime(t.year, t.month, t.day);
  }

  static DateTime? _graphTime(Object? value) {
    if (value is! Map) return null;
    final raw = '${value['dateTime']}';
    final zone = '${value['timeZone']}'.toUpperCase();
    final t = DateTime.tryParse(zone == 'UTC' && !raw.endsWith('Z') ? '${raw}Z' : raw);
    return t?.toLocal();
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  // --------------------------------------------------------------- TickTick

  /// TickTick's backup starts with a few lines about the file, then a row
  /// of column names that includes "List Name", "Title" and "taskId".
  static int _tickTickHeader(List<List<String>> rows) {
    for (var i = 0; i < rows.length && i < 15; i++) {
      final cells = rows[i].map((c) => c.trim()).toList();
      if (cells.contains('List Name') && cells.contains('Title') && cells.contains('taskId')) return i;
    }
    return -1;
  }

  static bool _isTickTick(List<List<String>> rows) => _tickTickHeader(rows) >= 0;

  (List<Task>, int) _tickTick(List<List<String>> rows, _Lists lists, DateTime now) {
    final h = _tickTickHeader(rows);
    final head = rows[h].map((c) => c.trim()).toList();
    String cell(List<String> row, String name) {
      final i = head.indexOf(name);
      return i < 0 || i >= row.length ? '' : row[i].trim();
    }

    final tasks = <Task>[];
    final byTickId = <String, int>{};
    final children = <(String, String, bool)>[];
    var skipped = 0;
    for (var r = h + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length < 3) continue;
      final title = cell(row, 'Title');
      // Status: 0 open, 1 or 2 done, -1 won't do.
      final status = cell(row, 'Status');
      if (title.isEmpty || status == '-1' || cell(row, 'Kind').toUpperCase() == 'NOTE') {
        skipped++;
        continue;
      }
      final tickId = cell(row, 'taskId');
      final parentId = cell(row, 'parentId');
      final done = status == '1' || status == '2';
      if (parentId.isNotEmpty) {
        children.add((parentId, title, done));
        continue;
      }
      final listName = cell(row, 'List Name');
      final listId = lists.idFor(listName, 'ticktick:$listName');
      final checklist = cell(row, 'Is Check list').toUpperCase() == 'Y';
      final content = cell(row, 'Content');
      final steps = <SubTask>[];
      final prose = <String>[];
      for (final line in content.split('\n')) {
        final l = line.trim();
        // ▫ open, ▪ ticked: how TickTick writes checklist items as text.
        if (checklist && (l.startsWith('▫') || l.startsWith('▪'))) {
          final text = l.substring(1).trim();
          if (text.isNotEmpty) {
            steps.add(SubTask(id: _id('sub', 'ticktick:$tickId|${steps.length}|$text'), title: text, isCompleted: l.startsWith('▪')));
          }
        } else if (l.isNotEmpty || prose.isNotEmpty) {
          prose.add(line);
        }
      }
      final created = _parseDate(cell(row, 'Created Time')) ?? now;
      final allDay = cell(row, 'Is All Day').toLowerCase() == 'true';
      final due = _parseDate(cell(row, 'Due Date'));
      final start = _parseDate(cell(row, 'Start Date'));
      final key = tickId.isEmpty ? '$listName|$title|$r' : tickId;
      byTickId[tickId] = tasks.length;
      tasks.add(Task(
        id: _id('task', 'ticktick:$key'),
        title: title,
        description: prose.join('\n').trim().ifEmptyNull,
        priority: switch (cell(row, 'Priority')) {
          '5' => TaskPriority.high,
          '3' => TaskPriority.medium,
          _ => TaskPriority.low,
        },
        startDate: start == null || allDay ? _day(start) : start,
        dueDate: due == null || allDay ? _day(due) : due,
        isCompleted: done,
        completedAt: done ? (_parseDate(cell(row, 'Completed Time')) ?? created) : null,
        tags: [
          for (final t in cell(row, 'Tags').split(','))
            if (t.trim().isNotEmpty) t.trim(),
        ],
        subTasks: steps,
        listId: listId,
        position: (tasks.length + 1) * 1024.0,
        createdAt: created,
        updatedAt: created,
      ));
    }
    for (final (parentId, title, done) in children) {
      final i = byTickId[parentId];
      if (i == null) {
        skipped++;
        continue;
      }
      final p = tasks[i];
      tasks[i] = p.copyWith(
        subTasks: [...p.subTasks, SubTask(id: _id('sub', 'ticktick:$parentId|${p.subTasks.length}|$title'), title: title, isCompleted: done)],
      );
    }
    return (tasks, skipped);
  }

  // ---------------------------------------------------------------- helpers

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static DateTime? _day(DateTime? t) => t == null ? null : DateTime(t.year, t.month, t.day);

  /// "2026-11-24", "2026-11-24 10:00", "2026-11-24T10:00:00+0000" (TickTick
  /// writes the zone without a colon). Anything else: null.
  static DateTime? _parseDate(String text) {
    final s = text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return null;
    final fixed = s.replaceFirstMapped(RegExp(r'([+-]\d{2})(\d{2})$'), (m) => '${m[1]}:${m[2]}');
    final t = DateTime.tryParse(fixed);
    if (t == null) return null;
    final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
    return dateOnly ? DateTime(t.year, t.month, t.day) : t.toLocal();
  }
}

/// Finds or creates the list each imported task goes to.
class _Lists {
  _Lists(List<TaskList> existing, this.now)
      : _byName = {for (final l in existing) l.name.trim().toLowerCase(): l},
        _position = existing.isEmpty ? 0.0 : existing.map((l) => l.position).reduce((a, b) => a > b ? a : b);

  final DateTime now;
  final Map<String, TaskList> _byName;
  double _position;
  final created = <TaskList>[];

  /// Names every app uses for its built-in list: they go to "My Tasks".
  static const _defaults = {'inbox', 'tasks', 'my tasks', 'משימות'};

  /// The list id for [name] (null: the default list).
  String? idFor(String? name, String key) {
    final n = name?.trim() ?? '';
    if (n.isEmpty || _defaults.contains(n.toLowerCase())) return null;
    final match = _byName[n.toLowerCase()];
    if (match != null) return match.isDefault ? null : match.id;
    final list = TaskList(
      id: OtherAppsImporter._id('list', key),
      name: n,
      position: ++_position,
      createdAt: now,
      updatedAt: now,
    );
    created.add(list);
    _byName[n.toLowerCase()] = list;
    return list.id;
  }
}

/// A small CSV reader: commas, double quotes ("" inside quotes), and line
/// breaks inside quoted cells.
class _Csv {
  static List<List<String>> parse(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((c) => c.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    row.add(cell.toString());
    if (row.any((c) => c.isNotEmpty)) rows.add(row);
    return rows;
  }
}

extension on String {
  String? get ifEmptyNull => trim().isEmpty ? null : this;
}
