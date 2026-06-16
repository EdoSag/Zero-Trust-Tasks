import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/backup_file_helper.dart';
import 'package:zero_trust_tasks/components/confirmation_dialog.dart';
import 'package:zero_trust_tasks/components/restore_preview_dialog.dart';
import 'package:zero_trust_tasks/components/settings/account_section.dart';
import 'package:zero_trust_tasks/components/settings/appearance_section.dart';
import 'package:zero_trust_tasks/components/settings/backup_section.dart';
import 'package:zero_trust_tasks/components/settings/danger_zone_section.dart';
import 'package:zero_trust_tasks/components/settings/security_section.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/services/vault_auth_service.dart';
import 'package:zero_trust_tasks/globals/sync_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/pages/onboarding_screen.dart';
import 'package:zero_trust_tasks/pages/sync_conflicts_page.dart';
import 'package:zero_trust_tasks/pages/templates_page.dart';

@NowaGenerated()
class SettingsPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() {
    return _SettingsPageState();
  }
}

enum _DeleteDataScope { cloud, local, all }

@NowaGenerated()
class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String? _message;

  final _vaultAuthService = VaultAuthService();
  final _localSecurityRepository = LocalSecurityRepository();

  @override
  void initState() {
    super.initState();
    SyncProvider.of(context, listen: false).checkRemoteStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = SupabaseService.instance.currentUser;
    final email = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email!
        : 'No active user';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Text(
          'Settings',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        AccountSection(
          email: email,
          isLoading: _isLoading,
          onSignOut: _handleSignOut,
        ),
        const SizedBox(height: 16),
        const SecuritySection(),
        const SizedBox(height: 16),
        BackupSection(
          isLoading: _isLoading,
          onSync: _handleSync,
          onBackup: _handleBackupToCloud,
          onRestore: _handleRestoreFromCloud,
          onExportFile: _handleExportToFile,
          onImportFile: _handleImportFromFile,
        ),
        const SizedBox(height: 16),
        const AppearanceSection(),
        const SizedBox(height: 16),
        _TemplatesSettingsTile(onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TemplatesPage()),
        )),
        const SizedBox(height: 16),
        DangerZoneSection(
          isLoading: _isLoading,
          onDeleteData: _showDeleteDataDialog,
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard(context),
        ],
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    final isError = _message!.contains('failed') ||
        _message!.contains('Error') ||
        _message!.contains('No ');
    final color = isError ? Colors.red : Colors.green;
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          _message!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    );
  }

  Future<void> _showDeleteDataDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete data'),
          content: const Text(
            'Choose what to delete: cloud data, local data, or all data.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteData(_DeleteDataScope.cloud);
              },
              child: const Text('Cloud data'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteData(_DeleteDataScope.local);
              },
              child: const Text('Local data'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _confirmAndDeleteAllData();
              },
              child: const Text('All data'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteAllData() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete all data?',
      message:
          'This permanently deletes your encrypted tasks from this device '
          'and the cloud. This cannot be undone.',
      confirmPhrase: 'DELETE',
      confirmButtonLabel: 'Delete all data',
    );
    if (!confirmed) {
      return;
    }
    await _deleteData(_DeleteDataScope.all);
  }

  Future<void> _deleteData(_DeleteDataScope scope) async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final taskManager = TaskManager.of(context);

      if (scope == _DeleteDataScope.cloud || scope == _DeleteDataScope.all) {
        await SupabaseService.instance.deleteEncryptedTasksDataForCurrentUser();
      }

      if (scope == _DeleteDataScope.local || scope == _DeleteDataScope.all) {
        await taskManager.clearAllTasks();
        await _localSecurityRepository.clearCloudVaultBlob();
      }

      if (!mounted) {
        return;
      }

      final status = switch (scope) {
        _DeleteDataScope.cloud => 'Cloud data deleted.',
        _DeleteDataScope.local => 'Local data deleted.',
        _DeleteDataScope.all => 'Cloud and local data deleted.',
      };

      setState(() {
        _message = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Delete failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSync() async {
    final syncProvider = SyncProvider.of(context, listen: false);
    syncProvider.setSyncing(true);
    setState(() => _message = null);
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
        if (!mounted) return;
        setState(() => _message =
            'Sync complete — ${result.conflicts.length} conflict(s) need resolution');
        return;
      }

      final summary = result.hadChanges
          ? 'Sync complete — ↑${result.uploaded} ↓${result.downloaded}'
          : 'Already up to date';
      setState(() => _message = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(summary), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Sync failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) syncProvider.setSyncing(false);
    }
  }

  Future<void> _handleBackupToCloud() async {
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
      if (!mounted) {
        return;
      }
      await SyncProvider.of(context, listen: false).markSynced();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Backup completed.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Backup failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
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

  Future<void> _handleRestoreFromCloud() async {
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

      final preview = await taskManager.previewBackup(dataBlob);
      if (!mounted) return;
      setState(() => _isLoading = false);

      final confirmed = await RestorePreviewDialog.show(
        context,
        preview: preview,
      );
      if (!confirmed || !mounted) return;

      setState(() {
        _isLoading = true;
        _message = null;
      });
      await _localSecurityRepository.saveCloudVaultBlob(dataBlob);
      await taskManager.restoreFromBackup(dataBlob);

      if (!mounted) {
        return;
      }
      await SyncProvider.of(context, listen: false).markSynced();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Restore completed.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Restore failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
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
          _message = 'Backup exported to your documents folder.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup file exported'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Export failed: $e';
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
      final encryptedPayload =
          await BackupFileHelper.readEncryptedPayloadFromFile();
      if (encryptedPayload == null || !mounted) {
        setState(() => _isLoading = false);
        return; // user cancelled file picker
      }

      final preview = await taskManager.previewBackup(encryptedPayload);
      if (!mounted) return;
      setState(() => _isLoading = false);

      final confirmed = await RestorePreviewDialog.show(
        context,
        preview: preview,
        confirmButtonLabel: 'Import',
      );
      if (!confirmed || !mounted) return;

      setState(() {
        _isLoading = true;
        _message = null;
      });
      await taskManager.restoreFromBackup(encryptedPayload);
      if (mounted) {
        setState(() {
          _message = 'Import completed.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Import failed: $e';
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

class _TemplatesSettingsTile extends StatelessWidget {
  const _TemplatesSettingsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Icon(Icons.article_outlined, color: theme.colorScheme.primary),
        title: const Text('Templates'),
        subtitle: const Text('Reusable task blueprints'),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
      ),
    );
  }
}
