import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/pages/main_screen.dart';
import 'package:zero_trust_tasks/pages/onboarding_screen.dart';

@NowaGenerated()
class AuthWrapper extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() {
    return _AuthWrapperState();
  }
}

@NowaGenerated()
class _AuthWrapperState extends State<AuthWrapper> {
  final _localSecurityRepository = LocalSecurityRepository();
  final _supabaseService = SupabaseService.instance;

  bool _isLoading = true;
  bool _isVaultInitialized = false;
  User? _currentUser;

  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null || !_isVaultInitialized) {
      return const OnboardingScreen();
    }

    return const MainScreen();
  }

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _supabaseService.onAuthStateChange.listen((_) {
      _refreshGuardState();
    });
    _refreshGuardState();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshGuardState() async {
    User? currentUser;
    var initialized = false;

    try {
      currentUser = _supabaseService.currentUser;
      initialized = await _localSecurityRepository.hasInitializedVault();

      if (currentUser != null && initialized && !EncryptionService.isUnlocked) {
        final keyBytes = await _localSecurityRepository.readDerivedKeyBytes();
        if (keyBytes == null || keyBytes.isEmpty) {
          initialized = false;
        } else {
          EncryptionService.setSessionKey(SecretKey(keyBytes));
        }
      }
    } catch (_) {
      currentUser = _supabaseService.currentUser;
      initialized = false;
    }

    if (mounted) {
      setState(() {
        _currentUser = currentUser;
        _isVaultInitialized = initialized;
        _isLoading = false;
      });
    }
  }
}
