import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/core/services/pending_actions_store.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/models/pending_task_action.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/places/task_place_reminders.dart';
import 'package:zt_places/zt_places.dart';

Future<void> pump([int ms = 400]) => Future<void>.delayed(Duration(milliseconds: ms));

Task task(String title, {bool done = false}) => Task(
  id: title.toLowerCase(),
  title: title,
  isCompleted: done,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

const home = ZtPlace(id: 'p1', name: 'Home', latitude: 32.08, longitude: 34.78);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ZtLocalStore store;
  late ZtPlaceRemindersFake phone;
  late ProviderContainer container;

  Future<void> put(String id, Map<String, Object?> json) =>
      store.put(LocalItem(itemId: id, updatedAt: DateTime.now().toUtc(), json: json));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = await ZtLocalStore.open(appKey: Uint8List.fromList(List.filled(32, 7)));
    phone = ZtPlaceRemindersFake();
    container = ProviderContainer(
      overrides: [
        tasksStoreProvider.overrideWithValue(store),
        ztSharedSpacesProvider.overrideWith((ref) async => throw StateError('no sharing in this test')),
        ztPlaceRemindersProvider.overrideWithValue(phone),
        remindersEnabledProvider.overrideWithValue(false),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    container.listen(placeRemindersProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await store.close();
  });

  Future<void> remind(Task t, {ZtPlaceTrigger trigger = ZtPlaceTrigger.arrive, DateTime? at}) {
    final r = TaskPlaceReminder(taskId: t.id, place: home, trigger: trigger, armedAt: at ?? DateTime.utc(2026, 11, 11));
    return put(TaskPlaceReminder.itemIdFor(t.id), placeRemindersCollection.encode(r));
  }

  test('open tasks with a place reminder are armed on the phone; done ones are not', () async {
    final milk = task('Milk');
    final bread = task('Bread', done: true);
    await put(milk.id, tasksCollection.encode(milk));
    await put(bread.id, tasksCollection.encode(bread));
    await remind(milk);
    await remind(bread, trigger: ZtPlaceTrigger.leave);
    await pump();
    expect(phone.watched.map((r) => r.payload), ['milk']);
    final alert = phone.watched.single;
    expect(alert.place, home);
    expect(alert.trigger, ZtPlaceTrigger.arrive);
    expect(alert.id, 'milk@${DateTime.utc(2026, 11, 11).millisecondsSinceEpoch}');
    // Titles stay out of the notification unless the user turned them on.
    expect(alert.title, isNot(contains('Milk')));
    expect(phone.style!.channelId, 'zt_tasks_place_reminders');

    // Ticking it off stops the alert.
    await put(milk.id, tasksCollection.encode(milk.copyWith(isCompleted: true)));
    await pump();
    expect(phone.watched, isEmpty);
  });

  test('turning task details off in notifications re-arms without the title', () async {
    final milk = task('Milk');
    await put(milk.id, tasksCollection.encode(milk));
    await container.read(settingsProvider).setShowTaskDetailsInNotifications(true);
    await remind(milk);
    await pump();
    expect(phone.watched.single.title, 'Milk');
    await container.read(settingsProvider).setShowTaskDetailsInNotifications(false);
    await pump();
    expect(phone.watched.single.title, isNot(contains('Milk')));
  });

  test('the place is kept apart from the task, so shared lists never carry it', () async {
    final milk = task('Milk');
    await put(milk.id, tasksCollection.encode(milk));
    await remind(milk);
    await pump();
    final stored = (await store.get(milk.id))!.json!;
    expect(stored.toString(), isNot(contains('32.08')));
    expect((await store.get(TaskPlaceReminder.itemIdFor('milk')))!.json!['kind'], 'place_reminder');
  });

  test('Done on the notification is queued like a reminder\'s Complete', () async {
    final milk = task('Milk');
    await put(milk.id, tasksCollection.encode(milk));
    await remind(milk);
    await pump();
    // (Forgetting the used-up alert then waits for sync, which this test
    // doesn't run.)
    container
        .read(placeRemindersProvider.notifier)
        .handle(ZtPlaceEvent(ZtPlaceEventType.done, phone.watched.single.id, 'milk'))
        .ignore();
    await pump(100);
    final queued = await const PendingActionsStore().pending();
    expect(queued.single.type, PendingTaskActionType.complete);
    expect(queued.single.taskId, 'milk');
  });
}
