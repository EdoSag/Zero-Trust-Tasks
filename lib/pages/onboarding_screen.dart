import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/services/vault_auth_service.dart';
import 'package:zero_trust_tasks/pages/main_screen.dart';

@NowaGenerated()
class OnboardingScreen extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() {
    return _OnboardingScreenState();
  }
}

@NowaGenerated()
class _OnboardingScreenState extends State<OnboardingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _vaultAuthService = VaultAuthService();
  final _localSecurityRepository = LocalSecurityRepository();

  bool _isLoading = false;
  bool _isBiometricSupported = false;
  bool _useBiometrics = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.security,
                  size: 82.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18.0),
                Text(
                  'Zero-Trust Tasks',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Create or unlock your secure vault with one shared Supabase account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                      ),
                ),
                const SizedBox(height: 28.0),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    hintText: 'At least 12 characters',
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Confirm Password (for create)',
                    hintText: 'Re-enter your master password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable biometrics on this device'),
                  subtitle: Text(
                    _isBiometricSupported
                        ? 'Biometric unlock can be used after sign-in.'
                        : 'Biometrics not available on this device.',
                  ),
                  value: _useBiometrics,
                  onChanged: _isBiometricSupported && !_isLoading
                      ? (value) {
                          setState(() {
                            _useBiometrics = value;
                          });
                        }
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 18.0),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createSecureVault,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20.0,
                          width: 20.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Text(
                          'CREATE SECURE VAULT',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 12.0),
                OutlinedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    'SIGN IN',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _isBiometricSupported = await _vaultAuthService.canUseBiometrics();
    final alreadyEnabled =
        await _localSecurityRepository.readBiometricEnabled();
    _useBiometrics = alreadyEnabled && _isBiometricSupported;

    final currentUser = SupabaseService.instance.currentUser;
    final hasVault = await _localSecurityRepository.hasInitializedVault();
    if (currentUser != null && hasVault && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _createSecureVault() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final validationError =
        _validateCommonInput(email: email, password: password);
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }
    if (confirm != password) {
      setState(() {
        _error = 'Confirm password must match the master password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _vaultAuthService.register(
        email: email,
        password: password,
        biometricEnabled: _useBiometrics,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on AuthRetryableFetchException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final validationError =
        _validateCommonInput(email: email, password: password);
    if (validationError != null) {
      setState(() {
        _error = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _vaultAuthService.signIn(
        email: email,
        password: password,
        biometricEnabled: _useBiometrics,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on AuthRetryableFetchException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatAuthError(e);
          _isLoading = false;
        });
      }
    }
  }

  String? _validateCommonInput({
    required String email,
    required String password,
  }) {
    if (email.isEmpty || !email.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 12) {
      return 'Master password must be at least 12 characters.';
    }
    return null;
  }

  String _formatAuthError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('authretryablefetchexception')) {
      return 'Cannot reach Supabase server (DNS/network issue). Check internet, disable VPN/ad-block DNS, and verify SUPABASE_URL.';
    }

    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or master password.';
    }

    if (message.contains('No salt is configured for the current user.')) {
      return 'Account exists, but profiles.salt is missing. This user must have a salt row in Supabase profiles.';
    }

    return message;
  }
}
