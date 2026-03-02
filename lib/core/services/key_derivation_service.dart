import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/config/env_config.dart';
import 'package:zero_trust_tasks/core/security/security_constants.dart';

@NowaGenerated()
class KeyDerivationService {
  KeyDerivationService._();

  static final Random _random = Random.secure();
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: SecurityConstants.pbkdf2Iterations,
    bits: SecurityConstants.pbkdf2KeyBits,
  );

  static Future<SecretKey> deriveKey({
    required String password,
    required List<int> salt,
  }) async {
    if (salt.length != SecurityConstants.pbkdf2SaltLength) {
      throw StateError(
        'Salt must be exactly ${SecurityConstants.pbkdf2SaltLength} bytes.',
      );
    }
    final passwordBytes = utf8.encode('${EnvConfig.appInternalSalt}:$password');
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: salt,
    );
  }

  static List<int> generateSalt() {
    return List<int>.generate(
      SecurityConstants.pbkdf2SaltLength,
      (_) => _random.nextInt(256),
    );
  }
}
