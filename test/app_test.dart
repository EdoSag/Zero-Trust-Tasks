import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/app/auth_providers.dart';
import 'package:zero_trust_tasks/data/task_collections.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_crypto.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_import.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_source.dart';
import 'package:zero_trust_tasks/main.dart';

import 'support/fake_account_backend.dart';
import 'support/fake_sync_backend.dart';

const email = 'edo@example.com';
const password = 'correct horse battery';
const pepper = 'test-pepper-1234567890';
const fast = KdfParams(iterations: 1000);
final legacySalt = base64Url.encode(List<int>.generate(16, (i) => 200 - i)).replaceAll('=', '');

class FakeUser extends Notifier<User?> {
  @override
  User? build() => null;

  void set(String? email) => state = email == null
      ? null
      : User(
          id: email,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-10-14T00:00:00Z',
          email: email,
        );
}

final fakeUserProvider = NotifierProvider<FakeUser, User?>(FakeUser.new);

class FakeLegacySource implements LegacyTasksSource {
  LegacyTasksData data = const LegacyTasksData();
  int reads = 0;
  @override
  Future<LegacyTasksData> read() async {
    reads++;
    return data;
  }
}

Map<String, dynamic> oldTask(String id, String title) => {
      'id': id,
      'title': title,
      'priority': 'medium',
      'isCompleted': false,
      'createdAt': '2026-01-01T10:00:00.000',
      'updatedAt': '2026-01-02T10:00:00.000',
    };

void main() {
  late ProviderContainer container;
  late FakeAccountBackend backend;
  late FakeSyncBackend server;
  late FakeLegacySource legacy;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    server = FakeSyncBackend();
    legacy = FakeLegacySource();
    container = ProviderContainer(
      overrides: [
        ztAppConfigProvider.overrideWithValue(tasksAppConfig),
        sharedPreferencesProvider.overrideWithValue(prefs),
        remindersEnabledProvider.overrideWithValue(false),
        ztSyncBackendProvider.overrideWithValue(server),
        ztDeviceIdStoreProvider.overrideWithValue(InMemoryDeviceIdStore()..id = 'test-device'),
        ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        ztLocalStoreProvider.overrideWith((ref) async {
          final appKey = ref.watch(
            vaultControllerProvider.select((v) => v is VaultUnlocked ? v.appKey : null),
          );
          if (appKey == null) throw const VaultIsLocked();
          final store = await ZtLocalStore.open(appKey: appKey);
          ref.onDispose(store.close);
          return store;
        }),
        authStateChangesProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
        currentUserProvider.overrideWith((ref) => ref.watch(fakeUserProvider)),
        accountServiceProvider.overrideWith(
          (ref) => AccountService(backend, params: fast, legacyParams: fast),
        ),
        legacyTasksSourceProvider.overrideWithValue(legacy),
        legacyTasksPepperProvider.overrideWithValue(pepper),
        legacyTasksKdfParamsProvider.overrideWithValue(fast),
      ],
    );
    backend = FakeAccountBackend(
      onUserChanged: (email) => container.read(fakeUserProvider.notifier).set(email),
    );
  });

  tearDown(() => container.dispose());

  /// Crypto and the database run on real timers; let them finish, and let
  /// page transitions finish too.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Locks (cancelling the auto-lock and sync timers) and closes the app.
  Future<void> finish(WidgetTester tester) async {
    container.read(vaultControllerProvider.notifier).lock();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ZeroTrustTasksApp()),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(tester);
  }

  Future<void> confirmRecoveryKey(WidgetTester tester) async {
    expect(find.text('Save your recovery key'), findsOneWidget);
    await tester.tap(find.text('I saved my recovery key somewhere safe'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);
  }

  Future<void> openTasksTab(WidgetTester tester) async {
    await tester.tap(find.text('Tasks').last);
    await settle(tester);
  }

  /// A user of the pre-core Tasks app: raw-password Supabase login, a
  /// `profiles.salt`, and tasks encrypted with the old peppered key.
  Future<List<int>> givenPreCoreAccount() async {
    backend.authPasswords[email] = password;
    backend.profiles[email] = ProfileRecord(legacySalt: legacySalt);
    final key = await LegacyTasksCrypto.deriveKey(
      password: password,
      pepper: pepper,
      salt: legacySalt,
      params: fast,
    );
    return key;
  }

  testWidgets('new account: recovery key first, then the app; lock and unlock', (tester) async {
    await start(tester);
    await tester.tap(find.text('Create a Zero-Trust account'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await settle(tester);
    expect(container.read(vaultControllerProvider), isA<VaultLocked>());
    await confirmRecoveryKey(tester);

    expect(find.text('Zero-Trust Tasks'), findsOneWidget);
    expect(container.read(legacyTasksImportProvider), isA<LegacyImportDone>());
    expect(legacy.reads, 0, reason: 'a core account has no pre-core data');

    container.read(vaultControllerProvider.notifier).lock();
    await settle(tester);
    expect(find.text('Zero-Trust Tasks is locked'), findsOneWidget);
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await settle(tester);
    expect(find.text('Zero-Trust Tasks'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('touches on pushed screens keep auto-lock from firing', (tester) async {
    await start(tester);
    await tester.tap(find.text('Create a Zero-Trust account'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await settle(tester);
    await confirmRecoveryKey(tester);
    await tester.runAsync(() => container.read(ztAutoLockProvider.notifier).set(const Duration(minutes: 1)));

    // An editor-like screen pushed over the app.
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Center(child: TextButton(onPressed: () {}, child: const Text('Edit')))),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Edit'));
      await tester.pump(const Duration(seconds: 40));
    }
    expect(container.read(vaultControllerProvider), isA<VaultUnlocked>());

    // Idle for the full minute: it locks, and the pushed screen is gone.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(container.read(vaultControllerProvider), isA<VaultLocked>());
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Zero-Trust Tasks is locked'), findsOneWidget);
    await finish(tester);
    await tester.pump(const Duration(seconds: 10)); // a sync retry timer
  });

  testWidgets('pre-core user on the same phone: signs in and sees their tasks, synced', (
    tester,
  ) async {
    final key = await tester.runAsync(givenPreCoreAccount);
    legacy.data = LegacyTasksData(
      localTasksBlob: await tester.runAsync(() => LegacyTasksCrypto.encrypt(
            jsonEncode([oldTask('a', 'Buy milk'), oldTask('b', 'Call the bank')]),
            key!,
          )),
      storedKey: key,
      salts: [legacySalt],
    );

    await start(tester);
    await signIn(tester);
    await confirmRecoveryKey(tester);
    await openTasksTab(tester);

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call the bank'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);

    // The account was upgraded the way every app expects: its key is the
    // pre-core one, so the other Zero-Trust apps keep reading their data.
    final profile = backend.profiles[email]!;
    expect(profile.keys!.legacyDek, isTrue);
    expect(profile.authUpgraded, isTrue);
    expect(backend.authPasswords[email], isNot(password), reason: 'the raw password is retired');

    // Moved into the synced store and uploaded, encrypted, for other devices.
    await settle(tester);
    expect(server.rows.keys, containsAll(['tasks/a', 'tasks/b']));

    // Once per device: running again doesn't read the old data again.
    final reads = legacy.reads;
    await tester.runAsync(() => container.read(legacyTasksImportProvider.notifier).retry());
    expect(legacy.reads, reads);

    // After a lock (this test store is in memory, so it comes back from the
    // server) the tasks are still there.
    container.read(vaultControllerProvider.notifier).lock();
    await settle(tester);
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await settle(tester);
    await openTasksTab(tester);
    expect(find.text('Buy milk'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('pre-core user on a new phone: asks for the password once', (tester) async {
    final key = await tester.runAsync(givenPreCoreAccount);
    legacy.data = LegacyTasksData(
      cloudTasksBlob: await tester.runAsync(
        () => LegacyTasksCrypto.encrypt(jsonEncode([oldTask('c', 'Renew passport')]), key!),
      ),
      salts: [legacySalt],
    );

    await start(tester);
    await signIn(tester);
    await confirmRecoveryKey(tester);
    await openTasksTab(tester);

    expect(find.text('Renew passport'), findsNothing);
    expect(find.text('Enter password'), findsOneWidget);

    await tester.tap(find.text('Enter password'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'not it');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);
    expect(container.read(legacyTasksImportProvider), isA<LegacyImportNeedsPassword>());
    expect(find.textContaining('didn\'t open your earlier tasks'), findsOneWidget);

    await tester.tap(find.text('Enter password'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextField, 'Password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);

    expect(find.text('Renew passport'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
    final store = container.read(tasksStoreProvider)!;
    expect((await tester.runAsync(() => tasksCollection.list(store)))!.single.title, 'Renew passport');
    await finish(tester);
  });
}
