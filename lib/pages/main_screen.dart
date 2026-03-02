import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/components/dashboard_page.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';
import 'package:zero_trust_tasks/components/settings_page.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/pages/onboarding_screen.dart';

@NowaGenerated()
class MainScreen extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() {
    return _MainScreenState();
  }
}

@NowaGenerated()
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _localSecurityRepository = LocalSecurityRepository();

  @override
  void initState() {
    super.initState();
    _guardAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DashboardPage(),
      const TasksListPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero-Trust Tasks'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Encryption: Active',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _guardAndLoad() async {
    final currentUser = SupabaseService.instance.currentUser;
    final hasVault = await _localSecurityRepository.hasInitializedVault();

    if (!mounted) {
      return;
    }

    if (currentUser == null || !hasVault) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
      return;
    }

    if (!EncryptionService.isUnlocked) {
      final keyBytes = await _localSecurityRepository.readDerivedKeyBytes();
      if (keyBytes == null || keyBytes.isEmpty) {
        if (!mounted) {
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
        return;
      }
      EncryptionService.setSessionKey(SecretKey(keyBytes));
    }

    if (!mounted) {
      return;
    }

    TaskManager.of(context).loadTasks();
  }
}
