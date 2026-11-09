import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_source.dart';

/// Where the one-time move of pre-core tasks stands on this device.
sealed class LegacyImportState {
  const LegacyImportState();
}

class LegacyImportIdle extends LegacyImportState {
  const LegacyImportIdle();
}

class LegacyImportWorking extends LegacyImportState {
  const LegacyImportWorking();
}

/// Old tasks exist but no key on this device opens them: the user types
/// their password once. [wrongPassword] after a password that didn't work.
class LegacyImportNeedsPassword extends LegacyImportState {
  const LegacyImportNeedsPassword({this.wrongPassword = false});
  final bool wrongPassword;
}

class LegacyImportDone extends LegacyImportState {
  const LegacyImportDone({this.imported = 0});
  final int imported;
}

/// Usually offline. Nothing is marked done, so it runs again on the next
/// unlock or retry.
class LegacyImportFailed extends LegacyImportState {
  const LegacyImportFailed(this.error);
  final Object error;
}

final legacyTasksSourceProvider = Provider<LegacyTasksSource>((ref) => DeviceLegacyTasksSource());

/// `APP_INTERNAL_SALT` from `.env`: the old Tasks app mixed it into the
/// password. Needed only to read pre-core data.
final legacyTasksPepperProvider = Provider<String>((ref) => dotenv.env['APP_INTERNAL_SALT'] ?? '');

/// KDF settings of the old app. Tests lower them.
final legacyTasksKdfParamsProvider = Provider<KdfParams>((ref) => KdfParams.current);

/// Moves tasks and templates written by the pre-core Tasks app (on this
/// device and in the old `encrypted_tasks` / `encrypted_task_items` tables)
/// into the synced store, once per device. Runs by itself whenever the
/// vault opens; [submitPassword] covers a device without the old key.
///
/// Old data is only read, never changed or deleted, so older app builds
/// still see it.
class LegacyTasksImport extends Notifier<LegacyImportState> {
  static const source = 'tasks-v1';
  bool _running = false;

  @override
  LegacyImportState build() {
    ref.listen(ztSyncEngineProvider, (_, next) {
      switch (next) {
        case AsyncData():
          unawaited(_run());
        case AsyncError():
          if (!_running) state = const LegacyImportIdle();
        default:
          break;
      }
    }, fireImmediately: true);
    return const LegacyImportIdle();
  }

  Future<void> submitPassword(String password) => _run(password: password);

  Future<void> retry() => _run();

  Future<void> _run({String? password}) async {
    if (_running) return;
    _running = true;
    try {
      state = const LegacyImportWorking();
      final engine = await ref.read(ztSyncEngineProvider.future);
      final vault = ref.read(vaultControllerProvider);
      if (vault is! VaultUnlocked) {
        state = const LegacyImportIdle();
        return;
      }
      final sync = ref.read(ztSyncControllerProvider.notifier);
      final store = engine.store;
      final ledger = store is LegacyImportLedger ? store as LegacyImportLedger : null;
      if (ledger != null && await ledger.legacyImportDone(source)) {
        ref.read(vaultControllerProvider.notifier).forgetLegacyKey();
        state = const LegacyImportDone();
        return;
      }
      final coreLegacyKey = vault.legacyKey;
      if (coreLegacyKey == null) {
        // An account created on the core: nothing from before to move.
        await sync.importLegacy([_importer((_) async => const <LegacyRecord>[])]);
        state = const LegacyImportDone();
        return;
      }

      final data = await ref.read(legacyTasksSourceProvider).read();
      if (!data.hasData) {
        await sync.importLegacy([_importer((_) async => const <LegacyRecord>[])]);
        state = const LegacyImportDone();
        return;
      }
      final key = await data.findKey(
        coreLegacyKey: coreLegacyKey,
        password: password,
        pepper: ref.read(legacyTasksPepperProvider),
        params: ref.read(legacyTasksKdfParamsProvider),
      );
      if (key == null) {
        state = LegacyImportNeedsPassword(wrongPassword: password != null);
        return;
      }
      try {
        final results = await sync.importLegacy([_importer((_) => data.records(key))]);
        state = LegacyImportDone(imported: results.fold(0, (n, r) => n + r.imported));
      } finally {
        key.fillRange(0, key.length, 0);
      }
    } on VaultIsLocked {
      state = const LegacyImportIdle();
    } on Object catch (e) {
      state = LegacyImportFailed(e);
    } finally {
      _running = false;
    }
  }

  static LegacyImporter _importer(Future<List<LegacyRecord>> Function(Uint8List) read) =>
      LegacyImporter(source: source, read: read);
}

final legacyTasksImportProvider =
    NotifierProvider<LegacyTasksImport, LegacyImportState>(LegacyTasksImport.new);
