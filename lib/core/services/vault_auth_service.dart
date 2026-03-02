import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/key_derivation_service.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/encryption_service.dart';

@NowaGenerated()
class VaultAuthService {
  VaultAuthService({
    SupabaseService? supabaseService,
    LocalSecurityRepository? localSecurityRepository,
    LocalAuthentication? localAuthentication,
  })  : _supabaseService = supabaseService ?? SupabaseService.instance,
        _localSecurityRepository =
            localSecurityRepository ?? LocalSecurityRepository(),
        _localAuthentication = localAuthentication ?? LocalAuthentication();

  final SupabaseService _supabaseService;
  final LocalSecurityRepository _localSecurityRepository;
  final LocalAuthentication _localAuthentication;

  Future<void> register({
    required String email,
    required String password,
    bool biometricEnabled = false,
  }) async {
    if (password.length < 12) {
      throw StateError('Master password must be at least 12 characters.');
    }

    final response = await _supabaseService.signUp(email, password);
    if (response.session == null) {
      throw StateError(
        'Sign up completed without an active session. Disable email verification in Supabase Auth settings.',
      );
    }

    final salt = await _localSecurityRepository.getOrCreateSalt();
    await _supabaseService.upsertSaltForCurrentUser(salt);
    await _initializeLocalVault(
      password: password,
      salt: salt,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool biometricEnabled = false,
    bool pullCloudBlob = true,
  }) async {
    final response = await _supabaseService.signIn(email, password);
    if (response.session == null) {
      throw StateError('Sign in failed. No active session returned.');
    }

    final salt = await _supabaseService.fetchSaltForCurrentUser();
    await _localSecurityRepository.saveSalt(salt);

    await _initializeLocalVault(
      password: password,
      salt: salt,
      biometricEnabled: biometricEnabled,
    );

    if (pullCloudBlob) {
      final blob =
          await _supabaseService.fetchEncryptedTasksBlobForCurrentUser();
      if (blob != null && blob.isNotEmpty) {
        await _localSecurityRepository.saveCloudVaultBlob(blob);
      }
    }
  }

  Future<void> signOut() async {
    EncryptionService.clearSessionKey();
    await _localSecurityRepository.clearAllSecurityState();
    await _supabaseService.signOut();
  }

  Future<void> _initializeLocalVault({
    required String password,
    required List<int> salt,
    required bool biometricEnabled,
  }) async {
    final SecretKey derivedKey = await KeyDerivationService.deriveKey(
      password: password,
      salt: salt,
    );

    EncryptionService.setSessionKey(derivedKey);
    await _localSecurityRepository.saveDerivedKey(derivedKey);
    await _localSecurityRepository.saveVerificationData(
      await EncryptionService.createVerificationData(),
    );
    await _localSecurityRepository.saveBiometricEnabled(
      biometricEnabled && await canUseBiometrics(),
    );
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuthentication.isDeviceSupported() &&
          await _localAuthentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }
}
