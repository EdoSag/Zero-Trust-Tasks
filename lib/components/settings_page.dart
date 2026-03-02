import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/core/services/vault_auth_service.dart';
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

enum _DeleteDataScope { cloud, local, all }

@NowaGenerated()
class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  String? _message;

  final _vaultAuthService = VaultAuthService();
  final _localSecurityRepository = LocalSecurityRepository();

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
          'Profile',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        _buildAccountCard(theme, email),
        const SizedBox(height: 20),
        if (_isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        _buildPrimaryButton(
          context: context,
          icon: Icons.cloud_upload_outlined,
          label: 'Sync To Cloud',
          onPressed: _isLoading ? null : _handleSyncToSupabaseVault,
        ),
        const SizedBox(height: 14),
        _buildSecondaryButton(
          context: context,
          icon: Icons.cloud_download_outlined,
          label: 'Pull From Cloud',
          onPressed: _isLoading ? null : _handleRestoreFromSupabaseVault,
        ),
        const SizedBox(height: 14),
        _buildOutlinedButton(
          context: context,
          icon: Icons.delete_outline,
          label: 'Delete Data',
          onPressed: _isLoading ? null : _showDeleteDataDialog,
        ),
        const SizedBox(height: 18),
        _buildDangerButton(
          context: context,
          icon: Icons.logout,
          label: 'Sign Out',
          onPressed: _isLoading ? null : _handleSignOut,
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard(context),
        ],
      ],
    );
  }

  Widget _buildAccountCard(ThemeData theme, String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildPrimaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style:
              const TextStyle(fontSize: 30 / 1.6, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style:
              const TextStyle(fontSize: 30 / 1.6, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.22),
          foregroundColor: theme.colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style:
              const TextStyle(fontSize: 30 / 1.6, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.outline, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style:
              const TextStyle(fontSize: 30 / 1.6, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
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
                await _deleteData(_DeleteDataScope.all);
              },
              child: const Text('All data'),
            ),
          ],
        );
      },
    );
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
          _message = 'Cloud sync completed.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Cloud sync failed: $e';
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
          _message = 'Cloud pull completed.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud pull completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Cloud pull failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud pull failed: $e'),
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
