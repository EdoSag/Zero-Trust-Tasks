import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

@NowaGenerated()
class EncryptionService {
  EncryptionService._();

  static String? _sessionKeyHex;

  static final _random = Random.secure();

  static bool get isUnlocked {
    return _sessionKeyHex != null;
  }

  static Future<String> deriveKey(String masterPassword, String salt) async {
    final saltBytes = base64.decode(salt);
    final passwordBytes = utf8.encode(masterPassword);
    var combined = <int>[];
    combined.addAll(passwordBytes);
    combined.addAll(saltBytes);
    var result = Uint8List.fromList(combined);
    for (var i = 0; i < 100000; i++) {
      var hash = 0;
      for (var byte in result) {
        hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
      }
      final hashBytes = <int>[];
      for (var j = 0; j < 32; j++) {
        hashBytes.add((hash >> (j * 8)) & 0xFF);
      }
      result = Uint8List.fromList(hashBytes);
    }
    return base64.encode(result);
  }

  static String generateSalt() {
    final saltBytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64.encode(saltBytes);
  }

  static void setSessionKey(String key) {
    _sessionKeyHex = key;
  }

  static void clearSessionKey() {
    _sessionKeyHex = null;
  }

  static String encryptData(String plaintext) {
    if (_sessionKeyHex == null) {
      throw Exception(
        'Session not unlocked. Please unlock with master password.',
      );
    }
    final keyBytes = base64.decode(_sessionKeyHex!);
    final iv = List<int>.generate(16, (_) => _random.nextInt(256));
    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = <int>[];
    for (var i = 0; i < plaintextBytes.length; i++) {
      final keyIndex = i % keyBytes.length;
      final ivIndex = i % iv.length;
      ciphertext.add(plaintextBytes[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
    }
    final result = {
      'iv': base64.encode(iv),
      'ciphertext': base64.encode(ciphertext),
      'length': plaintextBytes.length,
    };
    return base64.encode(utf8.encode(jsonEncode(result)));
  }

  static String decryptData(String encryptedData) {
    if (_sessionKeyHex == null) {
      throw Exception(
        'Session not unlocked. Please unlock with master password.',
      );
    }
    final decoded =
        jsonDecode(utf8.decode(base64.decode(encryptedData)))
            as Map<String, dynamic>;
    final keyBytes = base64.decode(_sessionKeyHex!);
    final iv = base64.decode(decoded['iv'] as String);
    final ciphertext = base64.decode(decoded['ciphertext'] as String);
    final length = decoded['length'] as int;
    final plaintext = <int>[];
    for (var i = 0; i < length; i++) {
      final keyIndex = i % keyBytes.length;
      final ivIndex = i % iv.length;
      plaintext.add(ciphertext[i] ^ keyBytes[keyIndex] ^ iv[ivIndex]);
    }
    return utf8.decode(plaintext);
  }

  static Future<bool> verifyPassword(
    String masterPassword,
    String storedSalt,
    String verificationData,
  ) async {
    try {
      final key = await deriveKey(masterPassword, storedSalt);
      setSessionKey(key);
      final decrypted = decryptData(verificationData);
      return decrypted == 'VERIFIED';
    } catch (e) {
      clearSessionKey();
      return false;
    }
  }

  static String createVerificationData() {
    return encryptData('VERIFIED');
  }
}
