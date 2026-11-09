import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_crypto.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_source.dart';

const fast = KdfParams(iterations: 1000);
const pepper = 'test-pepper-1234567890';
const password = 'correct horse battery';
// Unpadded base64url, as the old Tasks app stored it.
final salt = base64Url.encode(List<int>.generate(16, (i) => i * 7)).replaceAll('=', '');

Map<String, dynamic> task(String id, String title, String updatedAt, {String? deletedAt}) => {
      'id': id,
      'title': title,
      'priority': 'high',
      'isCompleted': false,
      'tags': ['work'],
      'subTasks': [
        {'id': '$id-s1', 'title': 'step', 'isCompleted': true},
      ],
      'deletedAt': deletedAt,
      'createdAt': '2026-01-01T10:00:00.000',
      'updatedAt': updatedAt,
    };

void main() {
  test('derives the same key as the pre-core app', () async {
    // KeyDerivationService.deriveKey in the old app.
    final old = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 1000, bits: 256).deriveKey(
      secretKey: SecretKey(utf8.encode('$pepper:$password')),
      nonce: ZtBase64.decode(salt),
    );
    final ours = await LegacyTasksCrypto.deriveKey(
      password: password,
      pepper: pepper,
      salt: salt,
      params: fast,
    );
    expect(ours, await old.extractBytes());

    // And not the core's legacy key (bare password), which is why Tasks
    // derives its own.
    final core = await Kdf.deriveMasterKey(password: password, salt: ZtBase64.decode(salt), params: fast);
    expect(ours, isNot(core));
  });

  test('opens a blob in the old EncryptionService format', () async {
    final key = await LegacyTasksCrypto.deriveKey(password: password, pepper: pepper, salt: salt, params: fast);
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(utf8.encode('VERIFIED'), secretKey: SecretKey(key));
    final blob = base64.encode(utf8.encode(jsonEncode({
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    })));
    expect(await LegacyTasksCrypto.decrypt(blob, key), 'VERIFIED');
    expect(await LegacyTasksCrypto.opens(blob, List.filled(32, 1)), isFalse);
  });

  group('findKey', () {
    late List<int> key;
    late String blob;
    setUp(() async {
      key = await LegacyTasksCrypto.deriveKey(password: password, pepper: pepper, salt: salt, params: fast);
      blob = await LegacyTasksCrypto.encrypt(jsonEncode([task('a', 'A', '2026-01-01T10:00:00.000')]), key);
    });

    test('uses the key the old app kept on this device', () async {
      final data = LegacyTasksData(localTasksBlob: blob, storedKey: key);
      expect(await data.findKey(pepper: pepper, params: fast), key);
    });

    test('derives it from the password and profiles.salt on a new device', () async {
      final data = LegacyTasksData(cloudTasksBlob: blob, salts: ['not-a-salt!', salt]);
      expect(await data.findKey(pepper: pepper, params: fast), isNull);
      expect(await data.findKey(pepper: pepper, params: fast, password: 'wrong'), isNull);
      expect(await data.findKey(pepper: pepper, params: fast, password: password), key);
    });

    test('a damaged local copy does not hide the cloud copy', () async {
      final data = LegacyTasksData(
        localTasksBlob: base64.encode(utf8.encode('{"nonce":"","ciphertext":"","mac":""}')),
        cloudTasksBlob: blob,
        salts: [salt],
      );
      expect(await data.findKey(pepper: pepper, params: fast, password: password), key);
      expect((await data.records(key)).single.itemId, 'a');
    });
  });

  test('merges device, cloud backup and per-task rows; newest copy wins', () async {
    final key = await LegacyTasksCrypto.deriveKey(password: password, pepper: pepper, salt: salt, params: fast);
    Future<String> seal(Object json) => LegacyTasksCrypto.encrypt(jsonEncode(json), key);

    final data = LegacyTasksData(
      localTasksBlob: await seal([
        task('a', 'A on phone', '2026-03-01T10:00:00.000'),
        task('b', 'B old', '2026-01-01T10:00:00.000'),
        task('gone', 'Deleted elsewhere', '2026-01-01T10:00:00.000'),
        task('trashed', 'In trash', '2026-01-01T10:00:00.000', deletedAt: '2026-02-01T10:00:00.000'),
      ]),
      cloudTasksBlob: await seal([
        task('a', 'A older backup', '2026-02-01T10:00:00.000'),
        task('c', 'Only in backup', '2026-01-05T10:00:00.000'),
      ]),
      localTemplatesBlob: await seal([
        {'id': 't1', 'title': 'Weekly review', 'priority': 'low', 'subTaskTitles': ['Inbox']},
      ]),
      cloudRows: [
        LegacyTaskRow(
          id: 'b',
          blob: await seal(task('b', 'B newer on tablet', '2026-04-01T10:00:00.000')),
          updatedAt: DateTime.utc(2026, 4, 1),
          deleted: false,
        ),
        LegacyTaskRow(id: 'gone', blob: null, updatedAt: DateTime.utc(2026, 5, 1), deleted: true),
        LegacyTaskRow(id: 'x', blob: 'not a blob', updatedAt: DateTime.utc(2026, 5, 1), deleted: false),
      ],
    );

    final records = await data.records(key);
    final byId = {for (final r in records) r.itemId: r.json};
    expect(byId.keys, unorderedEquals(['a', 'b', 'c', 'trashed', 't1']));
    expect(byId['a']!['title'], 'A on phone');
    expect(byId['b']!['title'], 'B newer on tablet');
    expect(byId['trashed']!['deletedAt'], isNotNull);
    expect((byId['a']!['subTasks'] as List).single, containsPair('isCompleted', true));

    // Records are in collection form, so the app reads them back.
    expect(tasksCollection.owns(byId['a']), isTrue);
    expect(templatesCollection.owns(byId['t1']), isTrue);
    expect(byId['t1']!['subTaskTitles'], ['Inbox']);
  });
}
