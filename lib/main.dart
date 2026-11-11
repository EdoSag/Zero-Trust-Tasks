import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/app/app_gate.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';

/// Store name stays "Zero-Trust Tasks"; the launcher shows "ZT Tasks".
const tasksAppConfig = ZtAppConfig(appId: 'tasks', displayName: 'Zero-Trust Tasks');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      throw StateError('SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final prefs = await SharedPreferences.getInstance();
    // English or Hebrew, as picked in Settings, from the first frame.
    await ZtLanguageController.preload();
    await NotificationService.instance.init();
    runApp(
      ProviderScope(
        overrides: [
          ztAppConfigProvider.overrideWithValue(tasksAppConfig),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Shared lists: only owners rename a list (enforced by the server too).
          ztSpacePolicyProvider.overrideWithValue(tasksSpacePolicy),
        ],
        child: const ZeroTrustTasksApp(),
      ),
    );
  } catch (e) {
    runApp(StartupErrorApp(errorMessage: e.toString()));
  }
}

class ZeroTrustTasksApp extends ConsumerWidget {
  const ZeroTrustTasksApp({super.key, this.home = const AppGate()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        title: 'ZT Tasks', // on-device task switcher label
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        debugShowCheckedModeBanner: false,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
        home: home,
        // Any touch on any screen, pushed routes and dialogs included,
        // counts as activity for auto-lock.
        builder: (context, child) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Startup aborted: $errorMessage', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
