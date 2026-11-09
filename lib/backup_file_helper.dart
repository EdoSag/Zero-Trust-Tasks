import 'dart:convert';
import 'dart:typed_data';

import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_crypto.dart';
import 'package:zero_trust_tasks/models/task.dart';

/// A `.ztasks` backup file that needs the password it was made with:
/// one written by the earlier app version (format 1).
class BackupNeedsPassword implements Exception {
  const BackupNeedsPassword(this.salt);
  final String salt;
}

class InvalidBackupFile implements Exception {
  const InvalidBackupFile(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads and writes `.ztasks` backup files.
///
/// Format 2 (this version): the task list sealed (AES-256-GCM) with the
/// app's key, so only this account can open it, on any device.
/// Format 1 (earlier versions): sealed with the old password-derived key
/// and its salt; opened with the password via [LegacyTasksCrypto].
abstract final class BackupFileHelper {
  static const _aad = 'zero-trust-tasks/backup/v2';
  static const extension = 'ztasks';

  static Future<Uint8List> encode(List<Task> tasks, List<int> appKey) async {
    final sealed = await SealedBox.sealString(
      jsonEncode([for (final t in tasks) t.toJson()]),
      appKey,
      aad: utf8.encode(_aad),
    );
    final file = jsonEncode({'version': 2, 'app': 'tasks', 'payload': base64.encode(sealed)});
    return Uint8List.fromList(utf8.encode(file));
  }

  /// Throws [BackupNeedsPassword] for a format-1 file when [password] is
  /// null, and [InvalidBackupFile] when it can't be opened.
  static Future<List<Task>> decode(
    List<int> bytes, {
    required List<int> appKey,
    String? password,
    required String pepper,
    KdfParams legacyParams = KdfParams.current,
  }) async {
    final Map<String, dynamic> file;
    try {
      file = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on Object {
      throw const InvalidBackupFile('This isn\'t a Zero-Trust Tasks backup file.');
    }
    final String json;
    switch (file['version']) {
      case 2:
        try {
          json = await SealedBox.openString(
            base64.decode(file['payload'] as String),
            appKey,
            aad: utf8.encode(_aad),
          );
        } on Object {
          throw const InvalidBackupFile('This backup belongs to another account.');
        }
      case 1:
        final salt = file['salt'] as String?;
        final payload = file['encrypted_payload'] as String?;
        if (salt == null || payload == null) {
          throw const InvalidBackupFile('This backup file is damaged.');
        }
        if (password == null) throw BackupNeedsPassword(salt);
        final key = await LegacyTasksCrypto.deriveKey(
          password: password,
          pepper: pepper,
          salt: salt,
          params: legacyParams,
        );
        try {
          json = await LegacyTasksCrypto.decrypt(payload, key);
        } on Object {
          throw const InvalidBackupFile('That password doesn\'t open this backup.');
        } finally {
          key.fillRange(0, key.length, 0);
        }
      default:
        throw const InvalidBackupFile('This backup is from a newer version of the app.');
    }
    final list = jsonDecode(json);
    if (list is! List) throw const InvalidBackupFile('This backup file is damaged.');
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) Task.fromJson(e),
    ];
  }
}
