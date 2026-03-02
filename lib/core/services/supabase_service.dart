import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_tasks/core/security/base64_url_helper.dart';

@NowaGenerated()
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();
  static const String _encryptedTasksTable = 'encrypted_tasks';

  SupabaseClient? get _maybeClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _client {
    final client = _maybeClient;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }
    return client;
  }

  User? get currentUser {
    return _maybeClient?.auth.currentUser;
  }

  Session? get currentSession {
    return _maybeClient?.auth.currentSession;
  }

  Stream<AuthState> get onAuthStateChange {
    final client = _maybeClient;
    if (client == null) {
      return const Stream<AuthState>.empty();
    }
    return client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    if (currentSession == null) {
      return;
    }
    await _client.auth.signOut();
  }

  Future<void> upsertSaltForCurrentUser(List<int> salt) async {
    final user = _requireCurrentUser();
    await _client.from('profiles').upsert({
      'id': user.id,
      'salt': Base64UrlHelper.encode(salt),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<List<int>> fetchSaltForCurrentUser() async {
    final user = _requireCurrentUser();
    final response = await _client
        .from('profiles')
        .select('salt')
        .eq('id', user.id)
        .single();
    final encoded = response['salt'] as String?;
    if (encoded == null || encoded.isEmpty) {
      throw StateError('No salt is configured for the current user.');
    }
    return Base64UrlHelper.decode(encoded);
  }

  Future<void> upsertEncryptedTasksBlobForCurrentUser(String dataBlob) async {
    final user = _requireCurrentUser();
    final payload = <String, dynamic>{
      'user_id': user.id,
      'data_blob': dataBlob,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client
          .from(_encryptedTasksTable)
          .upsert(payload, onConflict: 'user_id');
    } on PostgrestException catch (e) {
      if (e.code != '42P10') {
        rethrow;
      }

      // Fallback for schemas that still miss UNIQUE(user_id):
      // update existing row(s), insert if none exists.
      final updated = await _client
          .from(_encryptedTasksTable)
          .update(payload)
          .eq('user_id', user.id)
          .select('id');

      final updatedRows = updated as List<dynamic>;
      if (updatedRows.isEmpty) {
        await _client.from(_encryptedTasksTable).insert(payload);
      }
    }

    await _dedupeEncryptedTasksRowsForCurrentUser(user.id);
  }

  Future<String?> fetchEncryptedTasksBlobForCurrentUser() async {
    final user = _requireCurrentUser();
    final response = await _client
        .from(_encryptedTasksTable)
        .select('data_blob')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .order('id', ascending: false)
        .limit(1);

    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      return null;
    }
    return (rows.first as Map<String, dynamic>)['data_blob'] as String?;
  }

  Future<void> deleteEncryptedTasksDataForCurrentUser() async {
    final user = _requireCurrentUser();
    await _client.from(_encryptedTasksTable).delete().eq('user_id', user.id);
  }

  Future<void> _dedupeEncryptedTasksRowsForCurrentUser(String userId) async {
    final response = await _client
        .from(_encryptedTasksTable)
        .select('id')
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .order('id', ascending: false);

    final rows = response as List<dynamic>;
    if (rows.length <= 1) {
      return;
    }

    final keepId = (rows.first as Map<String, dynamic>)['id'];
    await _client
        .from(_encryptedTasksTable)
        .delete()
        .eq('user_id', userId)
        .neq('id', keepId);
  }

  User _requireCurrentUser() {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user session.');
    }
    return user;
  }
}
