import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// A named list of tasks, like "Groceries" or "Work". Synced as its own
/// encrypted item (kind `task_list`); tasks point to it by [Task.listId].
///
/// Tasks without a list belong to the default list, [defaultId]. It always
/// exists, can be renamed (which stores it like any other list) and can't
/// be deleted.
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    this.color,
    this.position = 0,
    this.extra = const {},
    required this.createdAt,
    required this.updatedAt,
    this.shared,
  });

  factory TaskList.create({required String name, int? color, double position = 0}) {
    final now = DateTime.now();
    return TaskList(
      id: const Uuid().v4(),
      name: name,
      color: color,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
  }

  static const defaultId = 'default';
  static const defaultName = 'My Tasks';

  /// The default list as it looks before anyone renames it.
  static final TaskList fallbackDefault = TaskList(
    id: defaultId,
    name: defaultName,
    position: -1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  static const _knownKeys = {'id', 'name', 'color', 'position', 'createdAt', 'updatedAt'};

  factory TaskList.fromJson(Map<String, dynamic> json) => TaskList(
        id: json['id'] as String,
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : defaultName,
        color: json['color'] as int?,
        position: (json['position'] as num?)?.toDouble() ?? 0,
        extra: {
          for (final e in json.entries)
            if (!_knownKeys.contains(e.key)) e.key: e.value,
        },
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  final String id;
  final String name;

  /// ARGB colour value, or null for the theme's default.
  final int? color;

  /// Order of the list in the picker (smaller first).
  final double position;
  final Map<String, dynamic> extra;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set for a list shared with other Zero-Trust users (kept in its own
  /// end-to-end encrypted shared space, not in the account's vault). Never
  /// stored: it comes from the space each time the list is read.
  final SharedListInfo? shared;

  bool get isDefault => id == defaultId;
  bool get isShared => shared != null;

  /// The list id of the shared list kept in space [spaceId].
  static String sharedId(String spaceId) => '$sharedPrefix$spaceId';
  static const sharedPrefix = 'space:';

  /// The space of a shared list's id, or null for the account's own lists.
  static String? spaceIdOf(String? listId) =>
      listId != null && listId.startsWith(sharedPrefix) ? listId.substring(sharedPrefix.length) : null;

  Color? get colorValue => color == null ? null : Color(color!);

  Map<String, dynamic> toJson() => {
        ...extra,
        'id': id,
        'name': name,
        if (color != null) 'color': color,
        'position': position,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  TaskList copyWith({String? name, int? color, bool clearColor = false, double? position}) =>
      TaskList(
        id: id,
        name: name ?? this.name,
        color: clearColor ? null : (color ?? this.color),
        position: position ?? this.position,
        extra: extra,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        shared: shared,
      );

  /// The same list, read from a shared space.
  TaskList withShared(SharedListInfo info) => TaskList(
        id: sharedId(info.spaceId),
        name: name,
        color: color,
        position: position,
        extra: extra,
        createdAt: createdAt,
        updatedAt: updatedAt,
        shared: info,
      );

  /// The colours offered when creating or editing a list.
  static const palette = <int>[
    0xFF1E88E5, // blue
    0xFF00ACC1, // cyan
    0xFF43A047, // green
    0xFFFDD835, // yellow
    0xFFFB8C00, // orange
    0xFFE53935, // red
    0xFFD81B60, // pink
    0xFF8E24AA, // purple
    0xFF6D4C41, // brown
    0xFF546E7A, // grey
  ];
}

/// Who a shared list belongs to, as this device knows it.
class SharedListInfo {
  const SharedListInfo({
    required this.spaceId,
    this.isAdmin = false,
    this.members = const [],
    this.joinCode,
    this.waiting = false,
    this.myUserId = '',
  });

  final String spaceId;

  /// This account, as the members list names it.
  final String myUserId;

  /// Owners can rename the list, invite, remove people and delete it.
  final bool isAdmin;
  final List<SpaceMember> members;

  /// While an invite this account answered waits for the owner: the code
  /// to compare with theirs.
  final String? joinCode;

  /// Joined, but the owner hasn't let this account in yet (or the list
  /// hasn't arrived on this phone yet).
  final bool waiting;
}

/// Which tasks the Tasks tab shows: every list, starred tasks, or one list.
/// Stored in settings as `all`, `starred` or `list:<id>`.
class TaskListScope {
  const TaskListScope._(this.kind, this.listId);

  const TaskListScope.all() : this._('all', null);
  const TaskListScope.starred() : this._('starred', null);
  const TaskListScope.list(String id) : this._('list', id);

  factory TaskListScope.parse(String? value) {
    if (value == 'starred') return const TaskListScope.starred();
    if (value != null && value.startsWith('list:')) return TaskListScope.list(value.substring(5));
    return const TaskListScope.all();
  }

  final String kind;
  final String? listId;

  bool get isAll => kind == 'all';
  bool get isStarred => kind == 'starred';
  bool get isList => kind == 'list';

  String get key => isList ? 'list:$listId' : kind;

  @override
  bool operator ==(Object other) => other is TaskListScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
