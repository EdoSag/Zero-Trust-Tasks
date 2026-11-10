import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

class GoogleTasksImportException implements Exception {
  const GoogleTasksImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a Google Tasks export turns into.
class GoogleTasksImport {
  const GoogleTasksImport({required this.lists, required this.tasks, required this.skipped});

  /// Lists to create (Google's "My Tasks" and lists whose name already
  /// exists here are not in it: their tasks go to the existing list).
  final List<TaskList> lists;
  final List<Task> tasks;

  /// Deleted or empty entries left out.
  final int skipped;
}

/// Reads Google Tasks from a Google Takeout export: the whole `.zip`, or
/// `Tasks/Tasks.json` from inside it. Everything is read on the phone.
///
/// Each Google list becomes a list here (matched by name to existing ones,
/// "My Tasks" to the default list). Subtasks (Google's `parent`) become
/// subtasks of their parent task. Ids are derived from Google's ids, so
/// importing the same file twice doesn't create duplicates.
class GoogleTasksImporter {
  const GoogleTasksImporter();

  static const _uuid = Uuid();

  static String _idFor(String kind, String googleId) =>
      _uuid.v5(Namespace.url.value, 'google-tasks:$kind:$googleId');

  GoogleTasksImport parse(Uint8List bytes, {required List<TaskList> existingLists}) {
    final json = _readJson(bytes);
    final lists = <TaskList>[];
    final tasks = <Task>[];
    var skipped = 0;
    final byName = {for (final l in existingLists) l.name.trim().toLowerCase(): l};
    var position = existingLists.isEmpty ? 0.0 : existingLists.last.position;

    final rawLists = json['items'];
    if (json['kind'] != 'tasks#taskLists' && rawLists is! List) {
      throw const GoogleTasksImportException('This isn\'t a Google Tasks export (Tasks.json).');
    }
    for (final rawList in (rawLists as List? ?? const [])) {
      if (rawList is! Map) continue;
      final title = (rawList['title'] as String?)?.trim();
      final googleListId = rawList['id'] as String? ?? title ?? 'list';
      String? listId;
      final match = title == null ? null : byName[title.toLowerCase()];
      if (title == null || title.isEmpty || title.toLowerCase() == TaskList.defaultName.toLowerCase()) {
        listId = null;
      } else if (match != null) {
        listId = match.isDefault ? null : match.id;
      } else {
        final created = TaskList(
          id: _idFor('list', googleListId),
          name: title,
          position: ++position,
          createdAt: DateTime.now(),
          updatedAt: _date(rawList['updated']) ?? DateTime.now(),
        );
        lists.add(created);
        byName[title.toLowerCase()] = created;
        listId = created.id;
      }

      final items = [
        for (final t in (rawList['items'] as List? ?? const []))
          if (t is Map) t.cast<String, dynamic>(),
      ];
      final live = <Map<String, dynamic>>[];
      for (final t in items) {
        final name = (t['title'] as String?)?.trim() ?? '';
        if (t['deleted'] == true || name.isEmpty) {
          skipped++;
        } else {
          live.add(t);
        }
      }
      // Google orders siblings by a zero-padded `position` string.
      live.sort((a, b) => ((a['position'] as String?) ?? '').compareTo((b['position'] as String?) ?? ''));
      final liveIds = {for (final t in live) t['id']};
      final children = <String, List<Map<String, dynamic>>>{};
      final roots = <Map<String, dynamic>>[];
      for (final t in live) {
        final parent = t['parent'] as String?;
        if (parent != null && liveIds.contains(parent)) {
          children.putIfAbsent(parent, () => []).add(t);
        } else {
          roots.add(t);
        }
      }
      var order = 0;
      for (final t in roots) {
        order++;
        final googleId = t['id'] as String? ?? '${googleListId}_$order';
        final completed = t['status'] == 'completed';
        final updated = _date(t['updated']) ?? DateTime.now();
        final notes = (t['notes'] as String?)?.trim();
        final links = [
          for (final l in (t['links'] as List? ?? const []))
            if (l is Map && l['link'] is String) l['link'] as String,
        ];
        tasks.add(Task(
          id: _idFor('task', googleId),
          title: (t['title'] as String).trim(),
          description: notes == null || notes.isEmpty ? null : notes,
          dueDate: _dueDate(t['due']),
          isCompleted: completed,
          completedAt: completed ? (_date(t['completed']) ?? updated) : null,
          starred: t['starred'] == true,
          links: links,
          listId: listId,
          position: order * 1024.0,
          subTasks: [
            for (final c in children[t['id']] ?? const <Map<String, dynamic>>[])
              SubTask(
                id: _idFor('task', c['id'] as String? ?? '${googleId}_${c['title']}'),
                title: (c['title'] as String).trim(),
                isCompleted: c['status'] == 'completed',
              ),
          ],
          createdAt: updated,
          updatedAt: updated,
        ));
      }
    }
    if (tasks.isEmpty && lists.isEmpty) {
      throw const GoogleTasksImportException('No tasks found in this file.');
    }
    return GoogleTasksImport(lists: lists, tasks: tasks, skipped: skipped);
  }

  Map<String, dynamic> _readJson(Uint8List bytes) {
    var data = bytes;
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (isZip) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.files.where((f) {
        final name = f.name.toLowerCase();
        return f.isFile && name.endsWith('.json') && name.contains('tasks');
      }).firstOrNull;
      if (entry == null) {
        throw const GoogleTasksImportException(
          'No Google Tasks found in this .zip. In Google Takeout, include "Tasks".',
        );
      }
      data = entry.content;
    }
    try {
      final decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the message below.
    }
    throw const GoogleTasksImportException('This isn\'t a Google Tasks export (Tasks.json).');
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// Google stores due dates as midnight UTC of the chosen day; keep the day.
  static DateTime? _dueDate(Object? value) {
    if (value is! String) return null;
    final utc = DateTime.tryParse(value)?.toUtc();
    return utc == null ? null : DateTime(utc.year, utc.month, utc.day);
  }
}
