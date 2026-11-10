import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_crypto.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_template.dart';

/// One row of the old per-task cloud table `encrypted_task_items`.
class LegacyTaskRow {
  const LegacyTaskRow({
    required this.id,
    required this.blob,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final String? blob;
  final DateTime updatedAt;
  final bool deleted;
}

/// Everything the pre-core Tasks app left behind, still encrypted.
class LegacyTasksData {
  const LegacyTasksData({
    this.localTasksBlob,
    this.localTemplatesBlob,
    this.cloudTasksBlob,
    this.cloudRows = const [],
    this.storedKey,
    this.salts = const [],
  });

  /// SharedPreferences `encrypted_tasks`: the whole list on this device.
  final String? localTasksBlob;

  /// SharedPreferences `encrypted_templates_v1`.
  final String? localTemplatesBlob;

  /// The newest `encrypted_tasks` row: the cloud backup of the whole list.
  final String? cloudTasksBlob;

  /// `encrypted_task_items`: per-task rows, tombstones included.
  final List<LegacyTaskRow> cloudRows;

  /// The old key the app kept in secure storage on this device, if any.
  final List<int>? storedKey;

  /// Salts the old key may have used: this device's copy and
  /// `profiles.salt`.
  final List<String> salts;

  bool get hasData =>
      localTasksBlob != null ||
      localTemplatesBlob != null ||
      cloudTasksBlob != null ||
      cloudRows.any((r) => !r.deleted && r.blob != null);

  /// Blobs to test a candidate key against. Several, so one damaged copy
  /// can't make the right key look wrong.
  List<String> get samples => [
        ?localTasksBlob,
        ?cloudTasksBlob,
        ?localTemplatesBlob,
        ...cloudRows.where((r) => !r.deleted && r.blob != null).map((r) => r.blob!).take(3),
      ];

  static Future<bool> _opensAny(List<String> blobs, List<int> key) async {
    for (final blob in blobs) {
      if (await LegacyTasksCrypto.opens(blob, key)) return true;
    }
    return false;
  }

  /// The first of [candidates] (the device's stored key, the core's legacy
  /// key, keys derived from [password] with each salt) that opens the old
  /// data, or null.
  Future<Uint8List?> findKey({
    Uint8List? coreLegacyKey,
    String? password,
    required String pepper,
    KdfParams params = KdfParams.current,
  }) async {
    final samples = this.samples;
    if (samples.isEmpty) return null;
    final candidates = <List<int>?>[storedKey, coreLegacyKey];
    for (final key in candidates) {
      if (key != null && key.length == 32 && await _opensAny(samples, key)) {
        return Uint8List.fromList(key);
      }
    }
    if (password == null || password.isEmpty) return null;
    for (final salt in {...salts}) {
      final Uint8List key;
      try {
        key = await LegacyTasksCrypto.deriveKey(
          password: password,
          pepper: pepper,
          salt: salt,
          params: params,
        );
      } on Object {
        continue; // a malformed salt
      }
      if (await _opensAny(samples, key)) return key;
      key.fillRange(0, key.length, 0);
    }
    return null;
  }

  /// Decrypts everything with [key] and merges it into one record per task
  /// and template, ready for [LegacyImporter]. For each task the newest
  /// copy wins (by its own `updatedAt`); a cloud tombstone newer than every
  /// copy removes it. Anything [key] can't open is skipped.
  Future<List<LegacyRecord>> records(List<int> key) async {
    final tasks = <String, Map<String, dynamic>>{};
    void offer(Map<String, dynamic> json) {
      final id = json['id'];
      if (id is! String || id.isEmpty) return;
      final current = tasks[id];
      if (current == null || _updatedAt(json).isAfter(_updatedAt(current))) {
        tasks[id] = json;
      }
    }

    for (final blob in [localTasksBlob, cloudTasksBlob]) {
      if (blob == null) continue;
      final list = await _openList(blob, key);
      for (final json in list) {
        offer(json);
      }
    }
    final tombstones = <String, DateTime>{};
    for (final row in cloudRows) {
      if (row.deleted) {
        tombstones[row.id] = row.updatedAt;
        continue;
      }
      final blob = row.blob;
      if (blob == null) continue;
      try {
        final json = jsonDecode(await LegacyTasksCrypto.decrypt(blob, key));
        if (json is Map<String, dynamic>) offer(json);
      } on Object {
        continue;
      }
    }
    tombstones.forEach((id, at) {
      final current = tasks[id];
      if (current != null && !_updatedAt(current).isAfter(at)) tasks.remove(id);
    });

    final out = <LegacyRecord>[];
    for (final json in tasks.values) {
      try {
        final task = Task.fromJson(json);
        out.add(LegacyRecord(itemId: task.id, json: tasksCollection.encode(task)));
      } on Object {
        continue; // a malformed old task
      }
    }
    if (localTemplatesBlob case final blob?) {
      for (final json in await _openList(blob, key)) {
        try {
          final template = TaskTemplate.fromJson(json);
          out.add(LegacyRecord(
            itemId: template.id,
            json: templatesCollection.encode(template),
          ));
        } on Object {
          continue;
        }
      }
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> _openList(String blob, List<int> key) async {
    try {
      final decoded = jsonDecode(await LegacyTasksCrypto.decrypt(blob, key));
      if (decoded is! List) return const [];
      return [for (final e in decoded) if (e is Map<String, dynamic>) e];
    } on Object {
      return const [];
    }
  }

  static DateTime _updatedAt(Map<String, dynamic> json) =>
      DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Reads [LegacyTasksData] from this device and the account's old tables.
abstract interface class LegacyTasksSource {
  /// Throws when the server can't be reached: the import must not be marked
  /// done without the cloud copy.
  Future<LegacyTasksData> read();
}

class DeviceLegacyTasksSource implements LegacyTasksSource {
  DeviceLegacyTasksSource({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  // Keys the pre-core app used.
  static const localTasksKey = 'encrypted_tasks';
  static const localTemplatesKey = 'encrypted_templates_v1';
  static const secureKeyKey = 'encrypted_db_key';
  static const secureSaltKey = 'vault_pbkdf2_salt';

  @override
  Future<LegacyTasksData> read() async {
    final prefs = await SharedPreferences.getInstance();
    String? nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s;

    Future<String?> secure(String key) async {
      try {
        return nonEmpty(await _secure.read(key: key));
      } on Object {
        return null; // unreadable after an OS or plugin change
      }
    }

    final storedKeyText = await secure(secureKeyKey);
    List<int>? storedKey;
    if (storedKeyText != null) {
      try {
        storedKey = ZtBase64.decode(storedKeyText);
      } on Object {
        storedKey = null;
      }
    }
    final deviceSalt = await secure(secureSaltKey);

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');

    final profile = await client.from('profiles').select('salt').eq('id', userId).maybeSingle();
    Future<List<Map<String, dynamic>>> rowsOrNone(
      Future<List<Map<String, dynamic>>> query,
    ) async {
      try {
        return await query;
      } on PostgrestException catch (e) {
        if (isMissingLegacyTable(e)) return const [];
        rethrow;
      }
    }

    final blobRows = await rowsOrNone(
      client
          .from('encrypted_tasks')
          .select('data_blob')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1),
    );
    final itemRows = await rowsOrNone(
      client
          .from('encrypted_task_items')
          .select('id, data_blob, updated_at, deleted')
          .eq('user_id', userId),
    );

    return LegacyTasksData(
      localTasksBlob: nonEmpty(prefs.getString(localTasksKey)),
      localTemplatesBlob: nonEmpty(prefs.getString(localTemplatesKey)),
      cloudTasksBlob: blobRows.isEmpty ? null : nonEmpty(blobRows.first['data_blob'] as String?),
      cloudRows: [
        for (final row in itemRows)
          LegacyTaskRow(
            id: row['id'] as String,
            blob: nonEmpty(row['data_blob'] as String?),
            updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
            deleted: row['deleted'] as bool? ?? false,
          ),
      ],
      storedKey: storedKey,
      salts: [
        ?deviceSalt,
        ?nonEmpty(profile?['salt'] as String?),
      ],
    );
  }
}

/// The pre-core tables were dropped from the database on 2026-11-10. A
/// missing table means there is nothing left to import.
bool isMissingLegacyTable(PostgrestException e) =>
    e.code == 'PGRST205' || e.code == '42P01';
