import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/security/base64_url_helper.dart';
import 'package:zero_trust_tasks/core/security/security_constants.dart';
import 'package:zero_trust_tasks/core/services/key_derivation_service.dart';

@NowaGenerated()
class LocalSecurityRepository {
  LocalSecurityRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  Future<List<int>> getOrCreateSalt() async {
    final existing = await readSalt();
    if (existing != null) {
      return existing;
    }
    final salt = KeyDerivationService.generateSalt();
    await saveSalt(salt);
    return salt;
  }

  Future<List<int>?> readSalt() async {
    final encoded =
        await _secureStorage.read(key: SecurityConstants.secureSaltKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return Base64UrlHelper.decode(encoded);
  }

  Future<void> saveSalt(List<int> salt) async {
    if (salt.length != SecurityConstants.pbkdf2SaltLength) {
      throw StateError(
        'Salt must be exactly ${SecurityConstants.pbkdf2SaltLength} bytes.',
      );
    }
    await _secureStorage.write(
      key: SecurityConstants.secureSaltKey,
      value: Base64UrlHelper.encode(salt),
    );
  }

  Future<bool> hasInitializedVault() async {
    final dbKey = await _secureStorage.read(
      key: SecurityConstants.secureEncryptedDbKey,
    );
    return dbKey != null && dbKey.isNotEmpty;
  }

  Future<void> saveDerivedKey(SecretKey secretKey) async {
    final bytes = await secretKey.extractBytes();
    await saveDerivedKeyBytes(bytes);
  }

  Future<void> saveDerivedKeyBytes(List<int> keyBytes) async {
    await _secureStorage.write(
      key: SecurityConstants.secureEncryptedDbKey,
      value: Base64UrlHelper.encode(keyBytes),
    );
  }

  Future<String?> readEncryptedDbKey() async {
    return _secureStorage.read(key: SecurityConstants.secureEncryptedDbKey);
  }

  Future<List<int>?> readDerivedKeyBytes() async {
    final encoded = await readEncryptedDbKey();
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return Base64UrlHelper.decode(encoded);
  }

  Future<void> saveVerificationData(String verificationData) async {
    await _secureStorage.write(
      key: SecurityConstants.secureVerificationData,
      value: verificationData,
    );
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: SecurityConstants.secureBiometricEnabled,
      value: enabled.toString(),
    );
  }

  Future<bool> readBiometricEnabled() async {
    final raw = await _secureStorage.read(
      key: SecurityConstants.secureBiometricEnabled,
    );
    return raw == 'true';
  }

  Future<void> saveCloudVaultBlob(String dataBlob) async {
    await _secureStorage.write(
      key: SecurityConstants.secureCloudVaultBlob,
      value: dataBlob,
    );
  }

  Future<String?> readCloudVaultBlob() async {
    return _secureStorage.read(key: SecurityConstants.secureCloudVaultBlob);
  }

  Future<void> clearCloudVaultBlob() async {
    await _secureStorage.delete(key: SecurityConstants.secureCloudVaultBlob);
  }

  Future<void> clearVaultInitialization() async {
    await _secureStorage.delete(key: SecurityConstants.secureEncryptedDbKey);
    await _secureStorage.delete(key: SecurityConstants.secureVerificationData);
  }

  Future<void> clearAllSecurityState() async {
    await _secureStorage.delete(key: SecurityConstants.secureEncryptedDbKey);
    await _secureStorage.delete(key: SecurityConstants.secureVerificationData);
    await _secureStorage.delete(key: SecurityConstants.secureSaltKey);
    await _secureStorage.delete(key: SecurityConstants.secureBiometricEnabled);
    await _secureStorage.delete(key: SecurityConstants.secureCloudVaultBlob);
  }
}
