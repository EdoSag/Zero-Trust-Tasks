import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/globals/app_state.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/globals/themes.dart';
import 'package:zero_trust_tasks/components/auth_wrapper.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/pages/login_screen.dart';
import 'package:zero_trust_tasks/pages/main_screen.dart';
import 'package:zero_trust_tasks/pages/setup_screen.dart';
import 'package:zero_trust_tasks/pages/tasks_list_page.dart';

@NowaGenerated()
late final SharedPreferences sharedPrefs;

@NowaGenerated()
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPrefs = await SharedPreferences.getInstance();

  runApp(const MyApp());
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
        create: (context) => AppState(),
        builder: (context, child) => MaterialApp(
          title: 'Zero-Trust Tasks',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
          routes: {
            'AddTaskScreen': (context) => const AddTaskScreen(),
            'LoginScreen': (context) => const LoginScreen(),
            'MainScreen': (context) => const MainScreen(),
            'SetupScreen': (context) => const SetupScreen(),
            'TasksListPage': (context) => const TasksListPage(),
          },
        ),
      ),
    );
  }
}
