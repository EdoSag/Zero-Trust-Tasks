import 'package:flutter/foundation.dart';

/// What Tasks needs of a ZT Notes note. Read from the encrypted Notes
/// items; tolerant of fields newer versions add.
@immutable
class LinkedNote {
  const LinkedNote({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = body.trim().split('\n').first.trim();
    return firstLine.isEmpty ? 'Untitled note' : firstLine;
  }

  /// The first line of the body that isn't the title.
  String get preview {
    for (final line in body.split('\n')) {
      final text = line.trim();
      if (text.isNotEmpty && text != displayTitle) return text;
    }
    return '';
  }

  /// A live note's JSON, or null for notebooks, tags and trashed notes.
  static LinkedNote? fromItem(String id, Map<String, Object?>? json, DateTime updatedAt) {
    // Notes never carry a `kind`; notebooks and tags do.
    if (json == null || json['kind'] != null) return null;
    if (json['trashedAt'] != null) return null;
    return LinkedNote(
      id: id,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      updatedAt: updatedAt,
    );
  }
}

/// What Tasks needs of a ZT Contacts contact: who it is and how to reach
/// them.
@immutable
class LinkedContact {
  const LinkedContact({
    required this.id,
    required this.name,
    this.emails = const [],
    this.phones = const [],
  });

  final String id;
  final String name;
  final List<String> emails;
  final List<String> phones;

  /// A phone number or email to show under the name.
  String get detail => phones.isNotEmpty ? phones.first : (emails.isNotEmpty ? emails.first : '');

  static LinkedContact? fromItem(String id, Map<String, Object?>? json) {
    if (json == null || json['kind'] != 'contact') return null;
    if (json['deletedAt'] != null || json['trashedAt'] != null) return null;
    String str(Object? v) => v is String ? v.trim() : '';
    // Plain strings, or `{value: ...}` / `{number: ...}` entries.
    List<String> strs(Object? v) => [
          if (v is List)
            for (final e in v)
              if (e is String && e.trim().isNotEmpty)
                e.trim()
              else if (e is Map)
                for (final key in const ['value', 'number', 'address', 'email'])
                  if (e[key] is String && (e[key] as String).trim().isNotEmpty) (e[key] as String).trim(),
        ];
    var name = str(json['displayName']);
    if (name.isEmpty) {
      name = '${str(json['firstName'])} ${str(json['lastName'])}'.trim();
    }
    if (name.isEmpty) name = str(json['company']);
    final emails = strs(json['emails']);
    final phones = strs(json['phones']);
    if (name.isEmpty) name = emails.isNotEmpty ? emails.first : (phones.isNotEmpty ? phones.first : '');
    if (name.isEmpty) return null;
    return LinkedContact(id: id, name: name, emails: emails, phones: phones);
  }
}
