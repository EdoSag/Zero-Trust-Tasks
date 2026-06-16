import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/components/settings/settings_section_card.dart';

/// Permanently destructive actions (item 17). Stronger confirmation for
/// "all data" deletion is handled by the caller (item 5).
class DangerZoneSection extends StatelessWidget {
  const DangerZoneSection({
    super.key,
    required this.isLoading,
    required this.onDeleteData,
  });

  final bool isLoading;
  final VoidCallback onDeleteData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      title: 'Danger Zone',
      icon: Icons.warning_amber_outlined,
      iconColor: theme.colorScheme.error,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onDeleteData,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
