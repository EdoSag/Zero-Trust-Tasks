import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/backup_file_helper.dart';
import 'package:zero_trust_tasks/core/services/other_apps_import.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_crypto.dart';
import 'package:zero_trust_tasks/models/task.dart';

class MemoryWriter implements TaskWriter {
  final saved = <String, Task>{};
  final deleted = <String>[];
  @override
  Future<void> save(Task task) async => saved[task.id] = task;
  @override
  Future<void> delete(String taskId) async => deleted.add(taskId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaskManager manager;
  late MemoryWriter writer;
  late StreamController<List<Task>> source;

  setUp(() {
    manager = TaskManager(reminders: false);
    writer = MemoryWriter();
    source = StreamController<List<Task>>();
    manager.attach(source: () => source.stream, writer: writer);
  });

  tearDown(() => manager.dispose());

  test('shows the store\'s tasks and writes every change through', () async {
    expect(manager.isLoading, isTrue);
    source.add([Task.create(title: 'One')]);
    await pumpEventQueue();
    expect(manager.isLoading, isFalse);
    expect(manager.tasks.single.title, 'One');

    final two = Task.create(title: 'Two');
    await manager.addTask(two);
    expect(manager.tasks.map((t) => t.title), ['One', 'Two']);
    expect(writer.saved[two.id]!.title, 'Two');

    await manager.toggleTaskComplete(two.id);
    expect(writer.saved[two.id]!.isCompleted, isTrue);
    expect(writer.saved[two.id]!.completedAt, isNotNull);

    await manager.deleteTask(two.id);
    expect(writer.saved[two.id]!.deletedAt, isNotNull);
    await manager.undoDelete();
    expect(writer.saved[two.id]!.deletedAt, isNull);

    await manager.permanentlyDeleteTask(two.id);
    expect(writer.deleted, [two.id]);
    expect(manager.tasks.map((t) => t.title), ['One']);
  });

  test('clearing a category in bulk really clears it', () async {
    final t = Task.create(title: 'Tagged', category: 'Work');
    source.add([t]);
    await pumpEventQueue();
    await manager.bulkSetCategory({t.id}, null);
    expect(writer.saved[t.id]!.category, isNull);
  });

  test('locking forgets the tasks and refuses changes', () async {
    source.add([Task.create(title: 'Secret')]);
    await pumpEventQueue();
    manager.attach();
    expect(manager.tasks, isEmpty);
    expect(() => manager.addTask(Task.create(title: 'x')), throwsStateError);
  });

  test('trash older than 30 days is emptied after unlock', () async {
    final old = Task.create(title: 'Old').copyWith(
      deletedAt: DateTime.now().subtract(const Duration(days: 31)),
    );
    final recent = Task.create(title: 'Recent').copyWith(
      deletedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    source.add([old, recent]);
    await pumpEventQueue();
    expect(writer.deleted, [old.id]);
    expect(manager.getTrashedTasks().single.id, recent.id);
  });

  test('importing adds new tasks and only newer copies of existing ones', () async {
    final mine = Task.create(title: 'Mine');
    source.add([mine]);
    await pumpEventQueue();
    final older = mine.copyWith(title: 'Older', updatedAt: mine.updatedAt.subtract(const Duration(days: 1)));
    final fresh = Task.create(title: 'Fresh');
    expect(manager.previewImport([older, fresh]).toAdd, 1);
    expect(manager.previewImport([older, fresh]).toUpdate, 0);
    expect(await manager.importTasks([older, fresh]), 1);
    expect(manager.tasks.map((t) => t.title), unorderedEquals(['Mine', 'Fresh']));
  });

  group('backup files', () {
    const fast = KdfParams(iterations: 1000);
    final appKey = List<int>.generate(32, (i) => i);

    test('this version\'s files open only with the same account key', () async {
      final tasks = [Task.create(title: 'Backed up')];
      final bytes = await BackupFileHelper.encode(tasks, appKey);
      final back = await BackupFileHelper.decode(bytes, appKey: appKey, pepper: 'p');
      expect(back.single.title, 'Backed up');
      expect(
        () => BackupFileHelper.decode(bytes, appKey: List.filled(32, 9), pepper: 'p'),
        throwsA(isA<InvalidBackupFile>()),
      );
    });

    test('files from the earlier version open with the password', () async {
      const salt = 'AAECAwQFBgcICQoLDA0ODw';
      final key = await LegacyTasksCrypto.deriveKey(password: 'pw', pepper: 'p', salt: salt, params: fast);
      final payload = await LegacyTasksCrypto.encrypt(jsonEncode([Task.create(title: 'Old file').toJson()]), key);
      final bytes = utf8.encode(jsonEncode({'version': 1, 'salt': salt, 'encrypted_payload': payload}));

      expect(
        () => BackupFileHelper.decode(bytes, appKey: appKey, pepper: 'p', legacyParams: fast),
        throwsA(isA<BackupNeedsPassword>()),
      );
      expect(
        () => BackupFileHelper.decode(bytes, appKey: appKey, pepper: 'p', password: 'nope', legacyParams: fast),
        throwsA(isA<InvalidBackupFile>()),
      );
      final tasks = await BackupFileHelper.decode(
        bytes,
        appKey: appKey,
        pepper: 'p',
        password: 'pw',
        legacyParams: fast,
      );
      expect(tasks.single.title, 'Old file');
    });
  });

  group('importing from another app again', () {
    Task imported(String title, {bool done = false}) {
      final t = Task(
        id: 'import-1',
        title: title,
        isCompleted: done,
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );
      return t.copyWith(extra: {OtherAppsImporter.importedAsKey: OtherAppsImporter.fingerprint(t)});
    }

    Future<void> start(List<Task> tasks) async {
      source.add(tasks);
      await pumpEventQueue();
    }

    test('an unchanged file keeps local edits and ticks', () async {
      await start([]);
      expect(await manager.importFromApp([imported('Plan')]), 1);
      final mine = manager.tasks.single;
      await manager.updateTask(mine.copyWith(notes: 'my notes'));
      await manager.toggleTaskComplete(mine.id);
      expect(manager.previewImportFromApp([imported('Plan')]).toUpdate, 0);
      expect(await manager.importFromApp([imported('Plan')]), 0);
      expect(manager.tasks.single.isCompleted, isTrue);
      expect(manager.tasks.single.notes, 'my notes');
    });

    test('a changed source updates the imported fields and keeps what only Tasks has', () async {
      await start([]);
      await manager.importFromApp([imported('Plan')]);
      await manager.updateTask(manager.tasks.single.copyWith(notes: 'my notes'));
      final newer = imported('Plan the trip', done: true);
      expect(manager.previewImportFromApp([newer]).toUpdate, 1);
      expect(await manager.importFromApp([newer]), 1);
      final t = manager.tasks.single;
      expect(t.title, 'Plan the trip');
      expect(t.isCompleted, isTrue);
      expect(t.notes, 'my notes');
      expect(t.extra[OtherAppsImporter.importedAsKey], newer.extra[OtherAppsImporter.importedAsKey]);
      // And importing that same file once more changes nothing.
      expect(await manager.importFromApp([newer]), 0);
    });

    test('tasks deleted here, or imported before fingerprints, are left alone', () async {
      final old = Task(id: 'import-1', title: 'Plan', createdAt: DateTime(2026, 11, 1), updatedAt: DateTime(2026, 11, 1));
      await start([old]);
      expect(await manager.importFromApp([imported('Plan the trip')]), 0);
      expect(manager.tasks.single.title, 'Plan');
    });
  });
}
