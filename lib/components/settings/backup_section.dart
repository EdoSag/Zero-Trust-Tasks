import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/core/utils/relative_time_formatter.dart';
import 'package:zero_trust_tasks/components/settings/settings_section_card.dart';
import 'package:zero_trust_tasks/globals/sync_provider.dart';

/// Backup/restore controls, sync status, and local file export/import
/// (items 4, 18, 26).
class BackupSection extends StatelessWidget {
  const BackupSection({
    super.key,
    required this.isLoading,
    required this.onBackup,
    required this.onRestore,
    required this.onExportFile,
    required this.onImportFile,
  });

  final bool isLoading;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onExportFile;
  final VoidCallback onImportFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = context.watch<SyncProvider>();

    return SettingsSectionCard(
      title: 'Backup',
      icon: Icons.cloud_outlined,
      children: [
        if (sync.lastSyncedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Last backed up: ${formatRelativeTime(sync.lastSyncedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (sync.hasNewerRemoteData)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_sync,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The cloud has newer data than your last backup.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : onRestore,
                  child: const Text('Restore'),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onBackup,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Back up to cloud'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onRestore,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Restore from cloud'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const Divider(height: 28),
        Text(
          'Auto backup',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<AutoBackupFrequency>(
          segments: AutoBackupFrequency.values
              .map(
                (f) => ButtonSegment(
                  value: f,
                  label: Text(f.displayName),
                ),
              )
              .toList(),
          selected: {sync.autoBackupFrequency},
          onSelectionChanged: (selection) {
            sync.setAutoBackupFrequency(selection.first);
          },
        ),
        const Divider(height: 28),
        Text(
          'Local file backup',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onExportFile,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Export file'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onImportFile,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Import file'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
