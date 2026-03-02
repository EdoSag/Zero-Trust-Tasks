import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/backup_file_helper.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/services/vault_auth_service.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/pages/onboarding_screen.dart';

@NowaGenerated()
class SettingsPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() {
    return _SettingsPageState();
  }
}

@NowaGenerated()
class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String? _message;

  final _vaultAuthService = VaultAuthService();
  final _localSecurityRepository = LocalSecurityRepository();

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.instance.currentUser?.id ?? 'No active user';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24.0),
        Text(
          'Backup & Sync',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Column(
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export to File'),
                subtitle: const Text('Save encrypted backup to device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleExportToFile,
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import from File'),
                subtitle: const Text('Restore from local backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleImportFromFile,
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: Icon(
                  Icons.cloud_upload,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Sync to Google Drive'),
                subtitle: const Text('Backup to your private Google Drive'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleExportToCloud,
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: Icon(
                  Icons.cloud_download,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Restore from Google Drive'),
                subtitle: const Text('Download backup from Google Drive'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleImportFromCloud,
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: Icon(
                  Icons.cloud_sync,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Sync to Supabase Tasks'),
                subtitle:
                    const Text('Upsert encrypted JSON blob in encrypted_tasks'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleSyncToSupabaseVault,
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: Icon(
                  Icons.cloud_done,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Restore from Supabase Tasks'),
                subtitle:
                    const Text('Pull encrypted JSON blob and restore locally'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoading ? null : _handleRestoreFromSupabaseVault,
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16.0),
          Card(
            color: _message!.contains('WARNING') || _message!.contains('failed')
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _message!.contains('WARNING') ||
                              _message!.contains('failed')
                          ? Colors.red
                          : Colors.green,
                    ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24.0),
        Text(
          'Account',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Signed-in User ID'),
                subtitle: Text(userId),
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                subtitle: const Text(
                  'Sign out from Supabase and return to onboarding',
                ),
                onTap: _isLoading ? null : _handleSignOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24.0),
        Text(
          'Security',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Security'),
                subtitle: const Text('AES-256 encryption active'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1.0),
              ListTile(
                leading: const Icon(Icons.key_off),
                title: const Text('Clear Session Key'),
                subtitle: const Text('Clear in-memory key without sign out'),
                onTap: _isLoading ? null : _clearSessionKey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24.0),
        Text(
          'About',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Trust Task Manager',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Security Features:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                _buildFeatureItem(context, 'AES-256-GCM encryption'),
                _buildFeatureItem(
                  context,
                  'PBKDF2 key derivation (600,000 iterations)',
                ),
                _buildFeatureItem(context, 'Zero-knowledge architecture'),
                _buildFeatureItem(context, 'Client-side encryption'),
                _buildFeatureItem(context, 'No password storage'),
                _buildFeatureItem(context, 'End-to-end encrypted backups'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  void _clearSessionKey() {
    EncryptionService.clearSessionKey();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session key cleared from memory')),
    );
  }

  Future<void> _handleExportToFile() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      await BackupFileHelper.exportToFile(taskManager);
      if (mounted) {
        setState(() {
          _message = 'Tasks exported successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks exported successfully to device storage'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Export failed: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleImportFromFile() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      await BackupFileHelper.importFromFile(taskManager);
      if (mounted) {
        setState(() {
          _message = 'Tasks imported successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks imported successfully from file'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExportToCloud() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      await BackupFileHelper.exportToCloud(taskManager);
      if (mounted) {
        setState(() {
          _message = 'Tasks synced to Google Drive!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks synced to Google Drive successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Cloud sync failed: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleImportFromCloud() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      await BackupFileHelper.importFromCloud(taskManager);
      if (mounted) {
        setState(() {
          _message = 'Tasks restored from Google Drive!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tasks restored from Google Drive successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSyncToSupabaseVault() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      final dataBlob = await taskManager.getEncryptedBackupData();
      await SupabaseService.instance.upsertEncryptedTasksBlobForCurrentUser(
        dataBlob,
      );
      if (mounted) {
        setState(() {
          _message = 'Encrypted tasks synced to Supabase.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted tasks synced to Supabase'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Supabase sync failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supabase sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRestoreFromSupabaseVault() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final taskManager = TaskManager.of(context);
      final dataBlob = await SupabaseService.instance
          .fetchEncryptedTasksBlobForCurrentUser();
      if (dataBlob == null || dataBlob.isEmpty) {
        throw Exception('No encrypted tasks data found for this user.');
      }
      await _localSecurityRepository.saveCloudVaultBlob(dataBlob);
      await taskManager.restoreFromBackup(dataBlob);

      if (mounted) {
        setState(() {
          _message = 'Encrypted tasks restored from Supabase.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encrypted tasks restored from Supabase'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Supabase restore failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supabase restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await _vaultAuthService.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'Sign out failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
