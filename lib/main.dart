import 'package:shared_preferences/shared_preferences.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_tasks/core/config/env_config.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/globals/app_state.dart';
import 'package:zero_trust_tasks/globals/settings_provider.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/globals/lock_provider.dart';
import 'package:zero_trust_tasks/globals/smart_filter_provider.dart';
import 'package:zero_trust_tasks/globals/sync_provider.dart';
import 'package:zero_trust_tasks/globals/template_provider.dart';
import 'package:zero_trust_tasks/globals/themes.dart';
import 'package:zero_trust_tasks/components/auth_wrapper.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/pages/login_screen.dart';
import 'package:zero_trust_tasks/pages/main_screen.dart';
import 'package:zero_trust_tasks/pages/onboarding_screen.dart';
import 'package:zero_trust_tasks/pages/setup_screen.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';

@NowaGenerated()
late final SharedPreferences sharedPrefs;

@NowaGenerated()
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPrefs = await SharedPreferences.getInstance();
  try {
    await EnvConfig.loadAndValidate();
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
    await NotificationService.instance.init();
    runApp(const MyApp());
  } catch (e) {
    runApp(StartupErrorApp(errorMessage: e.toString()));
  }
}

@NowaGenerated()
class MyApp extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaskManager>(
      create: (context) => TaskManager(),
      child: ChangeNotifierProvider<AppState>(
        create: (context) => AppState(sharedPrefs),
        child: ChangeNotifierProvider<SettingsProvider>(
          create: (context) => SettingsProvider(sharedPrefs),
          child: ChangeNotifierProvider<SyncProvider>(
            create: (context) => SyncProvider(sharedPrefs),
            child: ChangeNotifierProvider<LockProvider>(
              create: (context) => LockProvider(sharedPrefs),
              child: ChangeNotifierProvider<SmartFilterProvider>(
                create: (context) => SmartFilterProvider(sharedPrefs),
                child: ChangeNotifierProvider<TemplateProvider>(
                  create: (context) => TemplateProvider(sharedPrefs),
                  builder: (context, child) => MaterialApp(
                title: 'Zero-Trust Tasks',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: context.watch<AppState>().themeMode,
                debugShowCheckedModeBanner: false,
                home: const AuthWrapper(),
                routes: {
                  'AddTaskScreen': (context) => const AddTaskScreen(),
                  'LoginScreen': (context) => const LoginScreen(),
                  'MainScreen': (context) => const MainScreen(),
                  'OnboardingScreen': (context) => const OnboardingScreen(),
                  'SetupScreen': (context) => const SetupScreen(),
                  'TasksListPage': (context) => const TasksListPage(),
                },
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@NowaGenerated()
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
            child: Text(
              'Startup aborted: $errorMessage',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
