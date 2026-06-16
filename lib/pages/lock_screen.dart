import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/security/base64_url_helper.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/globals/lock_provider.dart';

/// Password / biometric re-authentication shown when the app auto-locks
/// (item 23). Pops itself on success.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _localSecurityRepository = LocalSecurityRepository();
  final _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final biometricEnabled =
          await _localSecurityRepository.readBiometricEnabled();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (mounted) {
        setState(() {
          _biometricAvailable = biometricEnabled && canCheck;
        });
      }
      if (_biometricAvailable) {
        _authenticateWithBiometrics();
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Zero-Trust Tasks',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!authenticated || !mounted) return;
      await _restoreKeyAndUnlock();
    } catch (_) {}
  }

  Future<void> _restoreKeyAndUnlock() async {
    final keyBytes = await _localSecurityRepository.readDerivedKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Could not restore session key. Please sign in again.';
        });
      }
      return;
    }
    EncryptionService.setSessionKey(SecretKey(keyBytes));
    if (mounted) {
      LockProvider.of(context, listen: false).unlock();
      Navigator.pop(context);
    }
  }

  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final saltBytes = await _localSecurityRepository.readSalt();
      final verificationData =
          await _localSecurityRepository.readVerificationData();

      if (saltBytes == null || verificationData == null) {
        setState(() {
          _error = 'Security data not found. Please sign in again.';
          _isLoading = false;
        });
        return;
      }

      final saltBase64 = Base64UrlHelper.encode(saltBytes);
      final verified = await EncryptionService.verifyPassword(
        password,
        saltBase64,
        verificationData,
      );

      if (!mounted) return;

      if (verified) {
        LockProvider.of(context, listen: false).unlock();
        Navigator.pop(context);
      } else {
        setState(() {
          _error = 'Incorrect password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unlock failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'App Locked',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your master password to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    onSubmitted: (_) => _unlockWithPassword(),
                    decoration: InputDecoration(
                      labelText: 'Master password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _unlockWithPassword,
                        child: const Text('Unlock'),
                      ),
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _authenticateWithBiometrics,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Use biometrics'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
