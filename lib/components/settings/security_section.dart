import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/components/encryption_info_sheet.dart';
import 'package:zero_trust_tasks/components/settings/settings_section_card.dart';

/// Security info and a link to the encryption explanation sheet (item 16).
/// Placeholder for future controls (auto-lock, biometric unlock).
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
        const SizedBox(height: 4),
        Text(
          'More security controls, such as auto-lock and biometric unlock, '
          'are coming soon.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
