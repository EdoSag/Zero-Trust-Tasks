import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:pointycastle/export.dart';

@NowaGenerated()
class EncryptionService {
  EncryptionService._();

  static const int _pbkdf2Iterations = 210000;
  static const int _keyLengthBytes = 32;
  static const int _nonceLengthBytes = 12;
  static const int _tagLengthBits = 128;
  static const Duration _sessionTimeout = Duration(minutes: 15);

  static String? _sessionKeyBase64;
  static Timer? _sessionTimer;

  static final _random = Random.secure();

  static bool get isUnlocked => _sessionKeyBase64 != null;

  static Future<String> deriveKey(String masterPassword, String salt) async {
    final saltBytes = base64.decode(salt);
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(
      Pbkdf2Parameters(saltBytes, _pbkdf2Iterations, _keyLengthBytes),
    );
    final derivedKey = derivator.process(Uint8List.fromList(utf8.encode(masterPassword)));
    return base64.encode(derivedKey);
  }

  static String generateSalt() {
    final saltBytes = List<int>.generate(_keyLengthBytes, (_) => _random.nextInt(256));
    return base64.encode(saltBytes);
  }

  static void setSessionKey(String keyBase64) {
    _sessionKeyBase64 = keyBase64;
    _restartSessionTimer();
  }

  static void clearSessionKey() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionKeyBase64 = null;
  }

  static void touchSession() {
    if (_sessionKeyBase64 != null) {
      _restartSessionTimer();
    }
  }

  static String encryptData(String plaintext) {
    final key = _requireKey();
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLengthBytes, (_) => _random.nextInt(256)),
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters<KeyParameter>(
          KeyParameter(key),
          _tagLengthBits,
          nonce,
          Uint8List(0),
        ),
      );

    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final payload = {
      'v': 1,
      'n': base64.encode(nonce),
      'c': base64.encode(encrypted),
    };
    touchSession();
    return base64.encode(utf8.encode(jsonEncode(payload)));
  }

  static String decryptData(String encryptedData) {
    final key = _requireKey();
    final decoded = jsonDecode(utf8.decode(base64.decode(encryptedData))) as Map<String, dynamic>;

    if (decoded['v'] != 1) {
      throw const FormatException('Unsupported encrypted payload version');
    }

    final nonce = base64.decode(decoded['n'] as String);
    final cipherTextWithTag = base64.decode(decoded['c'] as String);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters<KeyParameter>(
          KeyParameter(key),
          _tagLengthBits,
          nonce,
          Uint8List(0),
        ),
      );

    final plaintext = cipher.process(Uint8List.fromList(cipherTextWithTag));
    touchSession();
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
      final ok = decrypted == 'VERIFIED';
      if (!ok) {
        clearSessionKey();
      }
      return ok;
    } catch (_) {
      clearSessionKey();
      return false;
    }
  }

  static String createVerificationData() => encryptData('VERIFIED');

  static Uint8List _requireKey() {
    final key = _sessionKeyBase64;
    if (key == null) {
      throw Exception('Session not unlocked. Please unlock with master password.');
    }
    return Uint8List.fromList(base64.decode(key));
  }

  static void _restartSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, clearSessionKey);
  }
}
