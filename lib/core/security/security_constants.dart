import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class SecurityConstants {
  SecurityConstants._();

  static const String secureSaltKey = 'vault_pbkdf2_salt';
  static const String secureEncryptedDbKey = 'encrypted_db_key';
  static const String secureBiometricEnabled = 'biometric_enabled';
  static const String secureVerificationData = 'verification_data';
  static const String secureCloudVaultBlob = 'cloud_vault_blob';

  static const int pbkdf2Iterations = 600000;
  static const int pbkdf2KeyBits = 256;
  static const int pbkdf2SaltLength = 16;
}
