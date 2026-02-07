import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/google_drive_service.dart';
import 'package:zero_trust_tasks/pages/login_screen.dart';

@NowaGenerated()
class SettingsPage extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.lock),
                title: Text('Security'),
                subtitle: Text('AES-256-GCM + PBKDF2 active'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Sync backup to Google Drive'),
                subtitle: const Text('Stores encrypted blob in appDataFolder'),
                onTap: () => _syncToCloud(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: const Text('Restore backup from Google Drive'),
                subtitle: const Text('Downloads latest encrypted backup'),
                onTap: () => _restoreFromCloud(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Lock App'),
                subtitle: const Text('Clear session and lock'),
                onTap: () {
                  EncryptionService.clearSessionKey();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Trust Task Manager',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.1.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Security Features:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildFeatureItem(context, 'AES-256-GCM authenticated encryption'),
                _buildFeatureItem(context, 'PBKDF2-HMAC-SHA256 key derivation'),
                _buildFeatureItem(context, 'Secure enclave/keystore secret storage'),
                _buildFeatureItem(context, 'Client-side encrypted cloud backups'),
                _buildFeatureItem(context, 'No password storage'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _syncToCloud(BuildContext context) async {
    try {
      final encrypted = context.read<TaskManager>().getEncryptedBackupData();
      await GoogleDriveService.uploadEncryptedBackup(encrypted);
      _showSnack(context, 'Encrypted backup synced to Google Drive.');
    } catch (e) {
      _showSnack(context, 'Sync failed: $e');
    }
  }

  Future<void> _restoreFromCloud(BuildContext context) async {
    try {
      final encrypted = await GoogleDriveService.downloadEncryptedBackup();
      if (encrypted == null || encrypted.isEmpty) {
        _showSnack(context, 'No backup found in Google Drive app data.');
        return;
      }
      await context.read<TaskManager>().restoreFromBackup(encrypted);
      _showSnack(context, 'Backup restored from Google Drive.');
    } catch (e) {
      _showSnack(context, 'Restore failed: $e');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
