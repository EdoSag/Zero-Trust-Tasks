import 'dart:io' as io;
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/core/repositories/local_security_repository.dart';
import 'package:zero_trust_tasks/core/security/base64_url_helper.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/models/migration_package.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zero_trust_tasks/google_drive_helper.dart';

@NowaGenerated()
class BackupFileHelper {
  BackupFileHelper._();

  static final _localSecurityRepository = LocalSecurityRepository();

  /// Export tasks to a local file (.ztasks)
  static Future<void> exportToFile(TaskManager taskManager) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot export.');
    }
    final saltBytes = await _localSecurityRepository.readSalt();
    if (saltBytes == null) {
      throw Exception('Salt not found. Please re-authenticate.');
    }
    final salt = Base64UrlHelper.encode(saltBytes);
    final encryptedData = await taskManager.getEncryptedBackupData();
    final migrationPackage = MigrationPackage(
      version: 1,
      salt: salt,
      encryptedPayload: encryptedData,
    );
    final jsonString = migrationPackage.toJsonString();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/zero_trust_tasks_$timestamp.ztasks';
    final file = io.File(filePath);
    await file.writeAsString(jsonString);
  }

  /// Import tasks from a local file (.ztasks)
  static Future<void> importFromFile(TaskManager taskManager) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot import.');
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ztasks'],
    );
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }
    final filePath = result.files.first.path;
    if (filePath == null) {
      throw Exception('Invalid file path');
    }
    final file = io.File(filePath);
    final jsonString = await file.readAsString();
    final migrationPackage = MigrationPackage.fromJsonString(jsonString);
    final localSaltBytes = await _localSecurityRepository.readSalt();
    final localSalt =
        localSaltBytes == null ? null : Base64UrlHelper.encode(localSaltBytes);
    if (localSalt != migrationPackage.salt) {
      throw Exception(
        'WARNING: This backup was created with a different master password. You may need to re-authenticate with the original password.',
      );
    }
    await taskManager.restoreFromBackup(migrationPackage.encryptedPayload);
  }

  /// Export tasks to Google Drive
  static Future<void> exportToCloud(TaskManager taskManager) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot export to cloud.');
    }
    final saltBytes = await _localSecurityRepository.readSalt();
    if (saltBytes == null) {
      throw Exception('Salt not found. Please re-authenticate.');
    }
    final salt = Base64UrlHelper.encode(saltBytes);
    final encryptedData = await taskManager.getEncryptedBackupData();
    final migrationPackage = MigrationPackage(
      version: 1,
      salt: salt,
      encryptedPayload: encryptedData,
    );
    await GoogleDriveHelper.uploadBackup(migrationPackage);
  }

  /// Import tasks from Google Drive
  static Future<void> importFromCloud(TaskManager taskManager) async {
    if (!EncryptionService.isUnlocked) {
      throw Exception('Session locked. Cannot import from cloud.');
    }
    final migrationPackage = await GoogleDriveHelper.downloadBackup();
    if (migrationPackage == null) {
      throw Exception('No backup found on Google Drive');
    }
    final localSaltBytes = await _localSecurityRepository.readSalt();
    final localSalt =
        localSaltBytes == null ? null : Base64UrlHelper.encode(localSaltBytes);
    if (localSalt != migrationPackage.salt) {
      throw Exception(
        'WARNING: This backup was created with a different master password. You may need to re-authenticate with the original password.',
      );
    }
    await taskManager.restoreFromBackup(migrationPackage.encryptedPayload);
  }
}
