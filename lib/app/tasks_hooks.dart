import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_tasks/app/share_intake.dart';
import 'package:zero_trust_tasks/app/widget_launch.dart';
import 'package:zero_trust_tasks/core/services/home_widget_service.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';
import 'package:zero_trust_tasks/pages/task_details_screen.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/platform/links.dart';
import 'package:zero_trust_tasks/places/task_place_reminders.dart';
import 'package:zt_places/zt_places.dart';
import 'package:zero_trust_tasks/sharing/shared_list_pages.dart';

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
  StreamSubscription<void>? _links;
  StreamSubscription<ZtPlaceEvent>? _places;
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
      // Shared-list invites opened from a message or a scanned QR code.
      _links = IncomingLinks.instance.arrived.listen((_) => _takeLinks());
      // Location reminders: fired, "Done" and taps, also those queued while
      // the app was closed or locked.
      _places = ref.read(ztPlaceRemindersProvider).events.listen(_onPlaceEvent);
      WidgetsBinding.instance.addPostFrameCallback((_) => _collectPlaces());
      WidgetsBinding.instance.addPostFrameCallback((_) => _takeLinks());
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
    _links?.cancel();
    _places?.cancel();
    _widgetDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_applyPending());
      unawaited(_collectPlaces());
    }
  }

  bool _sharedApplied = false;

  void _onTasksChanged() {
    if (!mounted) return;
    final manager = ref.read(taskManagerProvider);
    if (manager.isLoading) return;
    if (manager.sharedReady && !_sharedApplied) {
      // Taps on shared-list tasks waited for those lists to be read.
      _sharedApplied = true;
      if (_loaded) {
        unawaited(_applyPending());
        _openWidgetLaunch();
      }
    }
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

  Future<void> _collectPlaces() async {
    if (!_platform || !mounted) return;
    try {
      await ref.read(placeRemindersProvider.notifier).forgetFiredWhileLocked();
      await ref.read(ztPlaceRemindersProvider).collect();
    } on Object catch (e) {
      debugPrint('Place reminder events not read: $e');
    }
  }

  Future<void> _onPlaceEvent(ZtPlaceEvent e) async {
    if (!mounted) return;
    await ref.read(placeRemindersProvider.notifier).handle(e);
    if (!mounted) return;
    if (e.type == ZtPlaceEventType.done) unawaited(_applyPending());
    if (e.type == ZtPlaceEventType.tap && e.payload.isNotEmpty) {
      ref.read(widgetLaunchProvider.notifier).set(Uri(scheme: 'zerotrusttasks', host: 'task', queryParameters: {'id': e.payload}));
    }
  }

  Future<void> _takeLinks() async {
    final links = await IncomingLinks.instance.take();
    for (final link in links) {
      if (!mounted) return;
      await joinSharedList(context, initialLink: link);
    }
  }

  void _scheduleWidgetWrite() {
    if (!_platform || !HomeWidgetService.isSupported) return;
    _widgetDebounce?.cancel();
    _widgetDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      final lists = ref.read(taskListProvider);
      final now = DateTime.now();
      Map<String, WidgetContent> scopesAt(DateTime at) => HomeWidgetService.scopesFor(
            tasks: ref.read(taskManagerProvider).tasks,
            lists: lists.lists,
            showTasks: settings.widgetShowTasks,
            now: at,
            resolveList: (id) => lists.byId(id).id,
          );
      unawaited(const HomeWidgetService().writeScopes(
        scopes: scopesAt(now),
        // What the widgets switch to after midnight, so Today stays right
        // while the app is closed.
        scopesTomorrow: scopesAt(DateTime(now.year, now.month, now.day + 1)),
        // And the rest of the week, for when it stays closed longer.
        scopesLater: {
          for (var i = 2; i <= HomeWidgetService.daysAhead; i++)
            if (DateTime(now.year, now.month, now.day + i) case final day) day: scopesAt(day),
        },
        day: now,
        lists: lists.lists,
        showTasks: settings.widgetShowTasks,
        defaultListId: settings.widgetListId,
      ));
    });
  }

  void _openWidgetLaunch() {
    if (!mounted || ref.read(taskManagerProvider).isLoading) return;
    final manager = ref.read(taskManagerProvider);
    final waiting = ref.read(widgetLaunchProvider);
    if (waiting == null) return;
    if (waiting.host == 'task' &&
        !manager.sharedReady &&
        !manager.tasks.any((t) => t.id == waiting.queryParameters['id'])) {
      return; // maybe a shared list's task: opened once shared lists are read
    }
    final uri = ref.read(widgetLaunchProvider.notifier).take();
    if (uri == null) return;
    final navigator = Navigator.of(context);
    if (uri.host == 'new-task') {
      // From a list's or Starred widget: the new task goes there.
      showQuickAdd(
        context,
        listId: uri.queryParameters['list'],
        starred: uri.queryParameters['starred'] == '1',
      );
    } else if (uri.host == 'shared') {
      // Text shared from another app: the editor opens filled in, and
      // nothing is saved until Save.
      final draft = sharedTaskDraft(
        subject: uri.queryParameters['subject'],
        text: uri.queryParameters['text'],
      );
      navigator.push(MaterialPageRoute<void>(builder: (_) => AddTaskScreen(draft: draft)));
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
    // Keeps the phone's place alerts in step with the tasks.
    ref.watch(placeRemindersProvider);
    ref.listen(taskListProvider, (_, _) => _scheduleWidgetWrite());
    ref.listen(settingsProvider, (_, _) => _scheduleWidgetWrite());
    ref.listen(widgetLaunchProvider, (_, uri) {
      if (uri != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openWidgetLaunch());
    });
    return widget.child;
  }
}
