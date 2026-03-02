import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class EnvConfig {
  EnvConfig._();

  static bool _loaded = false;

  static Future<void> loadAndValidate() async {
    if (!_loaded) {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    }
    _validate();
  }

  static String get supabaseUrl {
    return _readRequired('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    return _readRequired('SUPABASE_ANON_KEY');
  }

  static String get appInternalSalt {
    return _readRequired('APP_INTERNAL_SALT');
  }

  static bool get isDebugMode {
    return _readRequired('IS_DEBUG_MODE').toLowerCase() == 'true';
  }

  static int get syncIntervalHours {
    return int.parse(_readRequired('SYNC_INTERVAL_HOURS'));
  }

  static String _readRequired(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }

  static void _validate() {
    final parsedUrl = Uri.tryParse(supabaseUrl);
    if (parsedUrl == null ||
        !parsedUrl.hasScheme ||
        (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http')) {
      throw StateError('SUPABASE_URL is invalid.');
    }
    if (supabaseAnonKey.length < 20) {
      throw StateError('SUPABASE_ANON_KEY is invalid.');
    }
    if (appInternalSalt.length < 16) {
      throw StateError('APP_INTERNAL_SALT must be at least 16 characters.');
    }
    if (syncIntervalHours <= 0) {
      throw StateError('SYNC_INTERVAL_HOURS must be greater than zero.');
    }
  }
}
