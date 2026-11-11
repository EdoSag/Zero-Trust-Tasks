import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/app/tasks_hooks.dart';
import 'package:zero_trust_tasks/components/dashboard_page.dart';
import 'package:zero_trust_tasks/components/legacy_import_banner.dart';
import 'package:zero_trust_tasks/components/settings_page.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _selectedIndex = ref
      .read(settingsProvider)
      .lastSelectedTab
      .clamp(0, 2);

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    ref.read(settingsProvider).setLastSelectedTab(index);
  }

  void _showDataProtection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ZtDataProtectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const pages = [DashboardPage(), TasksListPage(), SettingsPage()];
    return TasksHooks(
      child: Scaffold(
        // Settings brings its own app bar.
        appBar: _selectedIndex == 2
            ? null
            : AppBar(
                titleSpacing: 16,
                title: const Row(
                  children: [
                    ZtBrandMark(app: ZtSuite.tasks, size: 32),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Zero-Trust Tasks',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: context.l10n.encryptedHowYourDataIs,
                    icon: Icon(
                      Icons.verified_user,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: _showDataProtection,
                  ),
                  SizedBox(width: 4),
                ],
              ),
        body: Column(
          children: [
            LegacyImportBanner(),
            Expanded(child: pages[_selectedIndex]),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: context.l10n.dashboard,
            ),
            NavigationDestination(
              icon: Icon(Icons.list_outlined),
              selectedIcon: Icon(Icons.list),
              label: context.l10n.tasks,
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: context.l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}
