import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/globals/settings_provider.dart';
import 'package:zero_trust_tasks/globals/smart_filter_provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/globals/template_provider.dart';

/// Loaded in `main` and overridden there (tests override it too).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

/// The account's encrypted local store while the vault is unlocked, else
/// null. Not `.value`: that keeps the closed store after a lock.
final tasksStoreProvider = Provider<ZtLocalStore?>((ref) {
  return switch (ref.watch(ztLocalStoreProvider)) {
    AsyncData(:final value) when value is ZtLocalStore => value,
    _ => null,
  };
});

Future<SyncController> _syncController(Ref ref) async {
  await ref.read(ztSyncEngineProvider.future);
  return ref.read(ztSyncControllerProvider.notifier);
}

/// Whether [TaskManager] schedules notifications. Tests turn it off.
final remindersEnabledProvider = Provider<bool>((ref) => true);

final taskManagerProvider = ChangeNotifierProvider<TaskManager>((ref) {
  final manager = TaskManager(reminders: ref.watch(remindersEnabledProvider));
  ref.listen<ZtLocalStore?>(tasksStoreProvider, (_, store) {
    manager.attach(
      source: store == null ? null : () => tasksCollection.watch(store),
      writer: store == null ? null : CoreTaskWriter(store: store, sync: () => _syncController(ref)),
    );
  }, fireImmediately: true);
  return manager;
});

final templateProvider = ChangeNotifierProvider<TemplateProvider>((ref) {
  final provider = TemplateProvider();
  ref.listen<ZtLocalStore?>(tasksStoreProvider, (_, store) {
    provider.attach(
      source: store == null ? null : templatesCollection.watch(store),
      save: store == null
          ? null
          : (t) async => templatesCollection.save(await _syncController(ref), store, t),
      delete: store == null
          ? null
          : (id) async => templatesCollection.delete(await _syncController(ref), id),
    );
  }, fireImmediately: true);
  return provider;
});

final settingsProvider = ChangeNotifierProvider<SettingsProvider>(
  (ref) => SettingsProvider(ref.watch(sharedPreferencesProvider)),
);

final smartFilterProvider = ChangeNotifierProvider<SmartFilterProvider>(
  (ref) => SmartFilterProvider(ref.watch(sharedPreferencesProvider)),
);

/// Reads (without listening) from widgets that have only a [BuildContext].
/// Widgets that rebuild on changes use `ref.watch` instead.
extension TasksProviders on BuildContext {
  ProviderContainer get _container => ProviderScope.containerOf(this, listen: false);
  TaskManager get taskManager => _container.read(taskManagerProvider);
  TemplateProvider get templates => _container.read(templateProvider);
  SettingsProvider get settings => _container.read(settingsProvider);
  SmartFilterProvider get smartFilters => _container.read(smartFilterProvider);
}
