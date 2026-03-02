import 'package:nowa_runtime/nowa_runtime.dart';
import 'dart:convert';

@NowaGenerated()
class MigrationPackage {
  MigrationPackage({
    required this.version,
    required this.salt,
    required this.encryptedPayload,
  });

  factory MigrationPackage.fromJson(Map<String, dynamic> json) {
    return MigrationPackage(
      version: json['version'] as int,
      salt: json['salt'] as String,
      encryptedPayload: json['encrypted_payload'] as String,
    );
  }

  final int version;

  final String salt;

  final String encryptedPayload;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'salt': salt,
      'encrypted_payload': encryptedPayload,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  static MigrationPackage fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return MigrationPackage.fromJson(json);
  }
}
