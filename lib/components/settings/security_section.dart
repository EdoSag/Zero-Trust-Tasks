import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/components/encryption_info_sheet.dart';
import 'package:zero_trust_tasks/components/settings/settings_section_card.dart';
import 'package:zero_trust_tasks/globals/lock_provider.dart';
import 'package:zero_trust_tasks/globals/settings_provider.dart';

/// Security controls: auto-lock timeout selector, "Lock now" button, and a
/// link to the encryption explanation sheet (items 16, 23).
class SecuritySection extends StatelessWidget {
  const SecuritySection({super.key});

  void _showEncryptionInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const EncryptionInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lockProvider = context.watch<LockProvider>();
    final settings = context.watch<SettingsProvider>();

    return SettingsSectionCard(
      title: 'Security',
      icon: Icons.shield_outlined,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.verified_user, color: theme.colorScheme.primary),
          title: const Text('How your data is encrypted'),
          subtitle: const Text('AES-256-GCM, key derived from your password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEncryptionInfo(context),
        ),
        const Divider(height: 24),
        Text(
          'Auto-lock',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<AutoLockDuration>(
            value: lockProvider.autoLockDuration,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: AutoLockDuration.values
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                lockProvider.setAutoLockDuration(value);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => lockProvider.lock(),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Lock now'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Show task details in notifications'),
          subtitle: const Text(
            'Off: reminders show generic text only (recommended)',
          ),
          value: settings.showTaskDetailsInNotifications,
          onChanged: (value) =>
              settings.setShowTaskDetailsInNotifications(value),
        ),
      ],
    );
  }
}
