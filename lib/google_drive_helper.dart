import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/google_auth_client.dart';
import 'package:zero_trust_tasks/models/migration_package.dart';
import 'dart:convert';

@NowaGenerated()
class GoogleDriveHelper {
  GoogleDriveHelper._();

  static const String _fileName = 'zero_trust_tasks_backup.ztasks';

  static const List<String> _scopes = const [
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// Sign in to Google and get authenticated Drive API
  static Future<DriveApi?> _getAuthenticatedDriveApi() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: _scopes);
      final account = await googleSignIn.signIn();
      if (account == null) {
        return null;
      }
      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      return DriveApi(authenticateClient);
    } catch (e) {
      print('Google Sign-In error: ${e}');
      rethrow;
    }
  }

  /// Upload migration package to Google Drive
  static Future<void> uploadBackup(MigrationPackage package) async {
    final driveApi = await _getAuthenticatedDriveApi();
    if (driveApi == null) {
      throw Exception('Google Sign-In cancelled');
    }
    try {
      final jsonString = package.toJsonString();
      final bytes = utf8.encode(jsonString);
      final existingFiles = await driveApi.files.list(
        q: 'name = \'${_fileName}\' and trashed = false',
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      final media = Media(Stream.value(bytes), bytes.length);
      final driveFile = File();
      driveFile.name = _fileName;
      driveFile.mimeType = 'application/json';
      if (existingFiles.files?.isNotEmpty ?? false) {
        final fileId = existingFiles.files?.first.id;
        if (fileId != null) {
          await driveApi.files.update(driveFile, fileId, uploadMedia: media);
        }
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
    } finally {
      final googleSignIn = GoogleSignIn(scopes: _scopes);
      await googleSignIn.signOut();
    }
  }

  /// Download migration package from Google Drive
  static Future<MigrationPackage?> downloadBackup() async {
    final driveApi = await _getAuthenticatedDriveApi();
    if (driveApi == null) {
      throw Exception('Google Sign-In cancelled');
    }
    try {
      final fileList = await driveApi.files.list(
        q: 'name = \'${_fileName}\' and trashed = false',
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      if (fileList.files?.isEmpty ?? true) {
        return null;
      }
      final fileId = fileList.files?.first.id;
      if (fileId == null) {
        return null;
      }
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: DownloadOptions.fullMedia,
              )
              as Media;
      final bytes = <int>[];
      await for (var chunk in media.stream) {
        bytes.addAll(chunk);
      }
      final jsonString = utf8.decode(bytes);
      return MigrationPackage.fromJsonString(jsonString);
    } finally {
      final googleSignIn = GoogleSignIn(scopes: _scopes);
      await googleSignIn.signOut();
    }
  }
}

@NowaGenerated()
extension on File {
  @NowaGenerated()
  set name(String name) {}
}

@NowaGenerated()
extension on FilesResource {
  @NowaGenerated()
  Future<void> create(File driveFile, {required Media uploadMedia}) async {}
}

@NowaGenerated()
extension on FileList {
  @NowaGenerated()
  List<File>? get files {
    return null;
  }
}
