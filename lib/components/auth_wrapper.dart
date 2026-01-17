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
  bool? _isSetup;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isSetup = prefs.getBool('is_setup') ?? false;
    if (mounted) {
      setState(() {
        _isSetup = isSetup;
      });
    }
  }

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
}
