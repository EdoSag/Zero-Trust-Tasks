import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityStorageService {
  SecurityStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _saltKey = 'zt_salt';
  static const _verificationKey = 'zt_verification_data';

  static Future<void> saveSetupSecrets({
    required String salt,
    required String verificationData,
  }) async {
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _verificationKey, value: verificationData);
  }

  static Future<String?> getSalt() => _storage.read(key: _saltKey);

  static Future<String?> getVerificationData() => _storage.read(key: _verificationKey);
}
