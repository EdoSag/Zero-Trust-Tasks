import 'package:zero_trust_tasks/core/services/supabase_service.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/globals/sync_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';

/// Runs a cloud backup when the configured frequency window has elapsed.
/// Failures are silently swallowed — auto-backup is best-effort and must
/// never disrupt the user (item 22).
class AutoBackupService {
  AutoBackupService._();

  static Future<void> maybeRunBackup({
    required TaskManager taskManager,
    required SyncProvider syncProvider,
  }) async {
    if (!EncryptionService.isUnlocked) return;
    if (SupabaseService.instance.currentUser == null) return;

    final frequency = syncProvider.autoBackupFrequency;
    if (frequency == AutoBackupFrequency.off) return;

    final lastSynced = syncProvider.lastSyncedAt;
    if (lastSynced != null) {
      final age = DateTime.now().toUtc().difference(lastSynced);
      if (frequency == AutoBackupFrequency.daily && age.inHours < 24) return;
      if (frequency == AutoBackupFrequency.weekly && age.inDays < 7) return;
    }

    try {
      final dataBlob = await taskManager.getEncryptedBackupData();
      await SupabaseService.instance
          .upsertEncryptedTasksBlobForCurrentUser(dataBlob);
      await syncProvider.markSynced();
    } catch (_) {
      // Best-effort: ignore errors silently.
    }
  }
}
