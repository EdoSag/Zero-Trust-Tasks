import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// How Tasks encrypted data before it moved onto Zero-Trust-Core. Kept only
/// to read that data once and move it into the synced store.
///
/// The old key was PBKDF2-SHA256 (600k rounds) over `"<pepper>:<password>"`
/// with the account's `profiles.salt`, where the pepper is the app's
/// `APP_INTERNAL_SALT`. That prefix is why it differs from the core's legacy
/// key (PBKDF2 over the bare password), so Tasks derives its own.
abstract final class LegacyTasksCrypto {
  static final _aes = AesGcm.with256bits();

  /// The old Tasks key for [password]. [salt] may be in any base64 dialect.
  static Future<Uint8List> deriveKey({
    required String password,
    required String pepper,
    required String salt,
    KdfParams params = KdfParams.current,
  }) =>
      Kdf.deriveMasterKey(
        password: '$pepper:$password',
        salt: ZtBase64.decode(salt),
        params: params,
      );

  /// Opens one old blob: base64 of a JSON object with base64 `nonce`,
  /// `ciphertext` and `mac` (AES-256-GCM). Throws
  /// [SecretBoxAuthenticationError] when [key] is wrong.
  static Future<String> decrypt(String blob, List<int> key) async {
    final decoded =
        jsonDecode(utf8.decode(base64.decode(blob.trim()))) as Map<String, dynamic>;
    final box = SecretBox(
      base64.decode(decoded['ciphertext'] as String),
      nonce: base64.decode(decoded['nonce'] as String),
      mac: Mac(base64.decode(decoded['mac'] as String)),
    );
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(clear);
  }

  /// Writes a blob in the old format. Only tests use it.
  static Future<String> encrypt(String plaintext, List<int> key) async {
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: SecretKey(key));
    final json = jsonEncode({
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    });
    return base64.encode(utf8.encode(json));
  }

  /// Whether [key] opens [blob].
  static Future<bool> opens(String blob, List<int> key) async {
    try {
      await decrypt(blob, key);
      return true;
    } on Object {
      return false;
    }
  }
}
