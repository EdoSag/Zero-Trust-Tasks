import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  static Future<GoogleSignInAccount> _signIn() async {
    final account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in cancelled');
    }
    return account;
  }

  static Future<drive.DriveApi> _api() async {
    final account = await _signIn();
    final headers = await account.authHeaders;
    return drive.DriveApi(_AuthenticatedClient(headers));
  }

  static Future<void> uploadEncryptedBackup(String encryptedBackup) async {
    final api = await _api();
    final fileName = 'zero_trust_tasks_backup.json';
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$fileName' and trashed=false",
      $fields: 'files(id, name)',
    );

    final media = drive.Media(Stream.value(utf8.encode(encryptedBackup)), encryptedBackup.length);
    final metadata = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder']
      ..mimeType = 'application/json';

    if ((list.files ?? []).isEmpty) {
      await api.files.create(metadata, uploadMedia: media);
    } else {
      await api.files.update(metadata, list.files!.first.id!, uploadMedia: media);
    }
  }

  static Future<String?> downloadEncryptedBackup() async {
    final api = await _api();
    final fileName = 'zero_trust_tasks_backup.json';
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$fileName' and trashed=false",
      orderBy: 'modifiedTime desc',
      pageSize: 1,
      $fields: 'files(id, name)',
    );

    final fileId = list.files?.isNotEmpty == true ? list.files!.first.id : null;
    if (fileId == null) {
      return null;
    }

    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final chunks = await media.stream.toList();
    final bytes = chunks.expand((chunk) => chunk).toList();
    return utf8.decode(bytes);
  }
}

class _AuthenticatedClient extends http.BaseClient {
  _AuthenticatedClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _baseClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _baseClient.send(request);
  }
}
