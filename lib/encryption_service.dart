import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/pointycastle.dart';

@NowaGenerated()
class EncryptionService {
  EncryptionService._();

  static SecretKey? _sessionKey;

  static final _random = Random.secure();

  static final _aesGcm = AesGcm.with256bits();

  static bool get isUnlocked {
    return _sessionKey != null;
  }

  /// Derives a secure key from password using PBKDF2-HMAC-SHA256
  /// with 100,000 iterations for resistance against brute-force attacks
  static Future<SecretKey> deriveKey(
    String masterPassword,
    String saltBase64,
  ) async {
    final saltBytes = base64.decode(saltBase64);
    final passwordBytes = utf8.encode(masterPassword);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(passwordBytes),
      nonce: saltBytes,
    );
    return derivedKey;
  }

  /// Generates a cryptographically secure random salt (32 bytes)
  static String generateSalt() {
    final saltBytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Sets the session key in memory (never persisted to disk)
  static void setSessionKey(SecretKey key) {
    _sessionKey = key;
  }

  /// Clears the session key from memory
  static void clearSessionKey() {
    _sessionKey = null;
  }

  /// Encrypts data using AES-256-GCM with authentication
  /// Returns base64-encoded JSON containing nonce, ciphertext, and MAC
  static Future<String> encryptData(String plaintext) async {
    if (_sessionKey == null) {
      throw Exception(
        'Session not unlocked. Please unlock with master password.',
      );
    }
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: _sessionKey,
    );
    final result = {
      'nonce': base64.encode(secretBox.nonce),
      'ciphertext': base64.encode(secretBox.cipherText),
      'mac': base64.encode(secretBox.mac.bytes),
    };
    return base64.encode(utf8.encode(jsonEncode(result)));
  }

  /// Decrypts data using AES-256-GCM with authentication verification
  /// Throws SecretBoxAuthenticationError if MAC is invalid (data tampered or wrong password)
  static Future<String> decryptData(String encryptedData) async {
    if (_sessionKey == null) {
      throw Exception(
        'Session not unlocked. Please unlock with master password.',
      );
    }
    try {
      final decoded =
          jsonDecode(utf8.decode(base64.decode(encryptedData)))
              as Map<String, dynamic>;
      final nonce = base64.decode(decoded['nonce'] as String);
      final ciphertext = base64.decode(decoded['ciphertext'] as String);
      final mac = base64.decode(decoded['mac'] as String);
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
      final plaintextBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: _sessionKey,
      );
      return utf8.decode(plaintextBytes);
    } on SecretBoxAuthenticationError catch (error) {
      throw Exception('Invalid password or corrupted data');
    }
  }

  /// Verifies the master password by attempting to decrypt verification data
  static Future<bool> verifyPassword(
    String masterPassword,
    String storedSalt,
    String verificationData,
  ) async {
    try {
      final key = await deriveKey(masterPassword, storedSalt);
      setSessionKey(key);
      final decrypted = await decryptData(verificationData);
      return decrypted == 'VERIFIED';
    } on SecretBoxAuthenticationError catch (error) {
      clearSessionKey();
      return false;
    } catch (e) {
      clearSessionKey();
      return false;
    }
  }

  /// Creates encrypted verification data for password validation
  static Future<String> createVerificationData() async {
    return await encryptData('VERIFIED');
  }
}
