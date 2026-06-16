import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/components/settings/settings_section_card.dart';
import 'package:zero_trust_tasks/globals/app_state.dart';

/// Theme mode selector (item 10).
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingsSectionCard(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.settings_suggest_outlined),
            ),
          ],
          selected: {appState.themeMode},
          onSelectionChanged: (selection) {
            appState.setThemeMode(selection.first);
          },
        ),
      ],
    );
  }
}
