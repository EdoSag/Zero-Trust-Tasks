import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/pages/login_screen.dart';
import 'package:zero_trust_tasks/pages/setup_screen.dart';

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
  final _secureStorage = FlutterSecureStorage();

  bool? _isSetup;

  @override
  Widget build(BuildContext context) {
    if (_isSetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isSetup!) {
      return const LoginScreen();
    } else {
      return const SetupScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final salt = await _secureStorage.read(key: 'salt');
    final isSetupValue = await _secureStorage.read(key: 'is_setup');
    if (mounted) {
      setState(() {
        _isSetup = (salt != null && isSetupValue == 'true');
      });
    }
  }
}
