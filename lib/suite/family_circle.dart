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
/// The circle gets a read-only copy, under the writing account's user id
/// (every account has a list called `default`, and list ids are only
/// unique per account): `tasks/list/<user>/<list id>` (kind `tasks.list`)
/// and one `tasks/item/<user>/<task id>` (kind `tasks.item`) per open task,
/// and per task done in the last week, each with the common
/// [ZtFamilySummary] (`due`, `done`, `list` = the list's item id). The
/// tasks stay in the list; this account's phones refresh the copy, and
/// deleted, moved and old done tasks, switched-off lists and deleted lists
/// are removed. Other members' copies are never touched.
abstract final class FamilyCircleLists {
  static const app = 'tasks';
  static const listKind = 'tasks.list';
  static const itemKind = 'tasks.item';

  /// Done tasks stay in the hub this long.
  static const keepDone = Duration(days: 7);

  static String listItemId(String user, String listId) =>
      ZtFamilySpace.itemId(app, 'list', '$user/$listId');
  static String taskItemId(String user, String taskId) =>
      ZtFamilySpace.itemId(app, 'item', '$user/$taskId');

  /// Whether a circle item is one [user] wrote: theirs to update or remove.
  static bool isMine(String itemId, String user) =>
      itemId.startsWith('$app/list/$user/') ||
      itemId.startsWith('$app/item/$user/');

  /// What circle [circleId] should hold of [user]'s [lists]: those shown
  /// there and their tasks. [inList] says whether a task is in a list
  /// (tasks with an unknown list belong to the default one).
  static Map<String, Map<String, Object?>> itemsFor(
    String circleId,
    String user,
    List<TaskList> lists,
    Iterable<Task> tasks,
    bool Function(TaskList list, Task task) inList,
    DateTime now,
  ) {
    final out = <String, Map<String, Object?>>{};
    for (final list in lists) {
      if (list.isShared || list.familyCircle != circleId) continue;
      final listId = listItemId(user, list.id);
      out[listId] = ZtFamilySummary(title: list.name, kind: listKind)
          .addTo({'kind': listKind, 'name': list.name});
      for (final t in tasks) {
        if (t.deletedAt != null || t.isArchived || !inList(list, t)) continue;
        if (t.isCompleted &&
            (t.completedAt == null ||
                now.difference(t.completedAt!) > keepDone)) {
          continue;
        }
        out[taskItemId(user, t.id)] = ZtFamilySummary(
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
  /// holds. [user]'s items that aren't wanted any more go (whether the
  /// list was switched off or deleted); everyone else's stay.
  static ({Map<String, Map<String, Object?>> save, Set<String> delete}) diff({
    required Iterable<LocalItem> existing,
    required Map<String, Map<String, Object?>> want,
    required String user,
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
          if (!want.containsKey(i.itemId) && isMine(i.itemId, user))
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
    for (final entry in state.entries) {
      final space = entry.space;
      if (space == null) continue;
      final user = space.codec.myUserId;
      if (user.isEmpty) continue;
      final changes = diff(
        existing: await space.store.all(),
        want: itemsFor(entry.info.id, user, lists, tasks, inList, now),
        user: user,
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
