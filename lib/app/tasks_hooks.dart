import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/app/widget_launch.dart';
import 'package:zero_trust_tasks/core/services/home_widget_service.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/pages/task_details_screen.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Whether [TasksHooks] talks to the platform (off in widget tests).
final platformHooksEnabledProvider = Provider<bool>((ref) => true);

/// Work that runs while the tasks are open: applies reminder and widget
/// taps made while the vault was locked, keeps the home-screen widget
/// current, and opens the screen a widget tap asked for.
class TasksHooks extends ConsumerStatefulWidget {
  const TasksHooks({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TasksHooks> createState() => _TasksHooksState();
}

class _TasksHooksState extends ConsumerState<TasksHooks> with WidgetsBindingObserver {
  StreamSubscription<void>? _actions;
  Timer? _widgetDebounce;
  bool _applying = false;
  bool _loaded = false;

  bool get _platform => ref.read(platformHooksEnabledProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_platform) {
      _actions = NotificationService.instance.actionQueued.listen((_) => _applyPending());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTasksChanged());
  }

  String? _widgetLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Settings → Language changed: write the widget again in the new one.
    final language = context.l10n.localeName;
    if (_widgetLanguage != null && _widgetLanguage != language) {
      _scheduleWidgetWrite();
      unawaited(NotificationService.instance.refreshLanguage().catchError((Object _) {}));
    }
    _widgetLanguage = language;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actions?.cancel();
    _widgetDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_applyPending());
  }

  void _onTasksChanged() {
    if (!mounted) return;
    final manager = ref.read(taskManagerProvider);
    if (manager.isLoading) return;
    if (!_loaded) {
      _loaded = true;
      unawaited(_applyPending());
      _openWidgetLaunch();
    }
    _scheduleWidgetWrite();
  }

  Future<void> _applyPending() async {
    if (!_platform || _applying || !mounted) return;
    final manager = ref.read(taskManagerProvider);
    if (manager.isLoading) return;
    _applying = true;
    try {
      const store = PendingActionsStore();
      final actions = await store.pending();
      if (actions.isEmpty || !mounted || manager.isLoading) return;
      // Each one leaves the queue as soon as it is saved: a lock or failed
      // write keeps the rest for the next unlock, and nothing is replayed.
      final changed = await manager.applyPendingActions(
        actions,
        onDone: (action) => store.acknowledge([action]),
      );
      if (changed > 0 && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(context.l10n.savedChanges(changed)),
        ));
      }
    } on Object catch (e) {
      debugPrint('Pending task actions not applied: $e');
    } finally {
      _applying = false;
    }
  }

  void _scheduleWidgetWrite() {
    if (!_platform || !HomeWidgetService.isSupported) return;
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      final lists = ref.read(taskListProvider);
      final listId = settings.widgetListId;
      final content = HomeWidgetService.contentFor(
        tasks: ref.read(taskManagerProvider).tasks,
        list: listId == null ? null : lists.byId(listId),
        showTasks: settings.widgetShowTasks,
        resolveList: (id) => lists.byId(id).id,
      );
      unawaited(const HomeWidgetService().write(content));
    });
  }

  void _openWidgetLaunch() {
    if (!mounted || ref.read(taskManagerProvider).isLoading) return;
    final uri = ref.read(widgetLaunchProvider.notifier).take();
    if (uri == null) return;
    final navigator = Navigator.of(context);
    if (uri.host == 'new-task') {
      showQuickAdd(context);
    } else if (uri.host == 'task') {
      final id = uri.queryParameters['id'];
      final task = ref.read(taskManagerProvider).tasks.where((t) => t.id == id).firstOrNull;
      if (task != null) {
        navigator.push(MaterialPageRoute<void>(builder: (_) => TaskDetailsScreen(task: task)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskManagerProvider, (_, _) => _onTasksChanged());
    ref.listen(taskListProvider, (_, _) => _scheduleWidgetWrite());
    ref.listen(settingsProvider, (_, _) => _scheduleWidgetWrite());
    ref.listen(widgetLaunchProvider, (_, uri) {
      if (uri != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openWidgetLaunch());
    });
    return widget.child;
  }
}
