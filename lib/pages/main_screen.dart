import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/services/auto_backup_service.dart';
import 'package:zero_trust_tasks/globals/lock_provider.dart';
import 'package:zero_trust_tasks/globals/settings_provider.dart';
import 'package:zero_trust_tasks/globals/sync_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/pages/lock_screen.dart';
import 'package:zero_trust_tasks/pages/sync_conflicts_page.dart';
import 'package:zero_trust_tasks/components/dashboard_page.dart';
import 'package:zero_trust_tasks/components/encryption_info_sheet.dart';
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
class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _selectedIndex;
  final _localSecurityRepository = LocalSecurityRepository();
  Timer? _lockTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = SettingsProvider.of(context, listen: false).lastSelectedTab;
    _guardAndLoad();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _scheduleLock();
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
      _checkLockAndResume();
    }
  }

  void _scheduleLock() {
    if (!mounted) return;
    final lockProvider = LockProvider.of(context, listen: false);
    if (lockProvider.autoLockDuration == AutoLockDuration.never) return;
    final delay = lockProvider.autoLockDuration.duration ?? Duration.zero;
    _lockTimer?.cancel();
    _lockTimer = Timer(delay, () {
      if (mounted) {
        LockProvider.of(context, listen: false).lock();
      }
    });
  }

  void _checkLockAndResume() {
    if (!mounted) return;
    final lockProvider = LockProvider.of(context, listen: false);
    if (lockProvider.isLocked) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LockScreen(),
          fullscreenDialog: true,
        ),
      );
    }
    _triggerAutoBackup();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork && mounted) {
      // Small delay to let the connection stabilise before syncing.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) unawaited(_handleAutoSync());
      });
    }
  }

  Future<void> _handleAutoSync() async {
    final syncProvider = SyncProvider.of(context, listen: false);
    if (syncProvider.isSyncing) return;
    if (SupabaseService.instance.currentUser == null) return;

    syncProvider.setSyncing(true);
    try {
      final result = await TaskManager.of(context).syncTasks(
        lastSyncedAt: syncProvider.lastSyncedAt,
      );
      if (!mounted) return;
      await syncProvider.markSynced();
      if (!mounted) return;
      if (result.hasConflicts) {
        syncProvider.setSyncing(false);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SyncConflictsPage(conflicts: result.conflicts),
          ),
        );
        return;
      }
    } catch (_) {
      // Auto-sync is best-effort; suppress errors to avoid interrupting the user.
    } finally {
      if (mounted) syncProvider.setSyncing(false);
    }
  }

  void _triggerAutoBackup() {
    if (!mounted) return;
    final taskManager = TaskManager.of(context);
    final syncProvider = SyncProvider.of(context, listen: false);
    AutoBackupService.maybeRunBackup(
      taskManager: taskManager,
      syncProvider: syncProvider,
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    SettingsProvider.of(context, listen: false).setLastSelectedTab(index);
  }

  void _showEncryptionInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const EncryptionInfoSheet(),
    );
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
          InkWell(
            onTap: _showEncryptionInfo,
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: 'Encryption details',
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
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
