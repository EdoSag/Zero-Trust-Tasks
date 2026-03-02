import 'dart:convert';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class Base64UrlHelper {
  Base64UrlHelper._();

  static String encode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<int> decode(String value) {
    var normalized = value.trim();
    final mod = normalized.length % 4;
    if (mod != 0) {
      normalized = normalized.padRight(normalized.length + (4 - mod), '=');
    }
    return base64Url.decode(normalized);
  }
}
