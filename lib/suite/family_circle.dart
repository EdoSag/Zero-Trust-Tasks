import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_list.dart';

/// S-10 and L-2: a list in the ZT Family circle's family hub (shopping,
/// chores). Only for lists whose owner chose a circle
/// ([TaskList.familyCircle]); everyone in that circle then sees the list's
/// name and tasks, so it is off until asked for.
///
/// The circle gets a read-only copy: `tasks/list/<list id>` (kind
/// `tasks.list`) and one `tasks/item/<task id>` (kind `tasks.item`) per open
/// task, and per task done in the last week, each with the common
/// [ZtFamilySummary] (`due`, `done`, `list` = the list's item id). The tasks
/// stay in the list; any phone of the list's people in the circle refreshes
/// the copy, and deleted, moved and old done tasks are removed.
abstract final class FamilyCircleLists {
  static const app = 'tasks';
  static const listKind = 'tasks.list';
  static const itemKind = 'tasks.item';

  /// Done tasks stay in the hub this long.
  static const keepDone = Duration(days: 7);

  static String listItemId(String listId) =>
      ZtFamilySpace.itemId(app, 'list', listId);
  static String taskItemId(String taskId) =>
      ZtFamilySpace.itemId(app, 'item', taskId);

  /// The list item an item of the circle belongs to: itself for a list,
  /// its summary's list for a task. Null for anything else.
  static String? listOf(LocalItem item) {
    if (!ZtFamilySpace.belongsTo(item.itemId, app)) return null;
    if (item.itemId.startsWith('$app/list/')) return item.itemId;
    return ZtFamilySummary.of(item.json)?.list;
  }

  /// What circle [circleId] should hold for [lists]: those shown there and
  /// their tasks. [inList] says whether a task is in a list (tasks with an
  /// unknown list belong to the default one).
  static Map<String, Map<String, Object?>> itemsFor(
    String circleId,
    List<TaskList> lists,
    Iterable<Task> tasks,
    bool Function(TaskList list, Task task) inList,
    DateTime now,
  ) {
    final out = <String, Map<String, Object?>>{};
    for (final list in lists) {
      if (list.familyCircle != circleId) continue;
      final listId = listItemId(list.id);
      out[listId] = ZtFamilySummary(title: list.name, kind: listKind)
          .addTo({'kind': listKind, 'name': list.name});
      for (final t in tasks) {
        if (t.deletedAt != null || t.isArchived || !inList(list, t)) continue;
        if (t.isCompleted &&
            (t.completedAt == null ||
                now.difference(t.completedAt!) > keepDone)) {
          continue;
        }
        out[taskItemId(t.id)] = ZtFamilySummary(
          title: t.title.trim(),
          kind: itemKind,
          due: t.dueDate,
          done: t.isCompleted,
          list: listId,
        ).addTo({'kind': itemKind, 'title': t.title.trim()});
      }
    }
    return out;
  }

  /// What to save and delete in one circle: [want] compared with what it
  /// holds. Items of lists this phone knows ([mine], list item ids) that
  /// aren't wanted any more go; other people's lists are left alone.
  static ({Map<String, Map<String, Object?>> save, Set<String> delete}) diff({
    required Iterable<LocalItem> existing,
    required Map<String, Map<String, Object?>> want,
    required Set<String> mine,
  }) {
    final have = <String, LocalItem>{
      for (final i in existing)
        if (!i.deleted && ZtFamilySpace.belongsTo(i.itemId, app)) i.itemId: i,
    };
    return (
      save: {
        for (final e in want.entries)
          if (jsonEncode(have[e.key]?.json) != jsonEncode(e.value))
            e.key: e.value,
      },
      delete: {
        for (final i in have.values)
          if (!want.containsKey(i.itemId) && mine.contains(listOf(i)))
            i.itemId,
      },
    );
  }

  /// Brings every circle this phone is in up to date.
  static Future<void> sync(
    SpacesController circles,
    SpacesState state, {
    required List<TaskList> lists,
    required Iterable<Task> tasks,
    required bool Function(TaskList list, Task task) inList,
    required DateTime now,
  }) async {
    final mine = {for (final l in lists) listItemId(l.id)};
    for (final entry in state.entries) {
      final space = entry.space;
      if (space == null) continue;
      final changes = diff(
        existing: await space.store.all(),
        want: itemsFor(entry.info.id, lists, tasks, inList, now),
        mine: mine,
      );
      for (final e in changes.save.entries) {
        await circles.save(entry.info.id, e.key, e.value);
      }
      for (final id in changes.delete) {
        await circles.delete(entry.info.id, id);
      }
    }
  }
}

/// A ZT Family circle this account is in, by name.
typedef FamilyCircle = ({String id, String name});

/// The ZT Family circles this account is in and can write to.
final familyCirclesProvider = FutureProvider<List<FamilyCircle>>((ref) async {
  final state = ref.watch(ztFamilySpacesProvider);
  final out = <FamilyCircle>[];
  for (final e in state.entries) {
    final space = e.space;
    if (space == null) continue;
    final item = await space.store.get('family.circle');
    final name = item == null || item.deleted
        ? ''
        : (item.json?['name'] as String? ?? '').trim();
    out.add((id: e.info.id, name: name));
  }
  return out;
});
