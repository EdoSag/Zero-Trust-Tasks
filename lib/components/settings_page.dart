import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/backup_file_helper.dart';
import 'package:zero_trust_tasks/core/services/google_tasks_import.dart';
import 'package:zero_trust_tasks/components/restore_preview_dialog.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_import.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/pages/templates_page.dart';
import 'package:zero_trust_tasks/pages/trash_page.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// The shared Zero-Trust settings (account, security, appearance, other
/// apps, delete account) with Tasks' own rows.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return ZtSettingsPage(
      showSyncStatus: true,
      onSignedOut: () {},
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      onDataExported: (file, export) => _saveExport(context, ref, export),
      backupSection: [
        ListTile(
          leading: const Icon(Icons.move_to_inbox_outlined),
          title: Text(context.l10n.importFromGoogleTasks),
          subtitle: Text(context.l10n.yourGoogleTakeoutZipOr),
          onTap: () => _importGoogle(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(context.l10n.exportBackupFile),
          subtitle: Text(context.l10n.encryptedOnlyYourAccountCan),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(context.l10n.importBackupFile),
          subtitle: Text(context.l10n.addsTasksFromAZtasks),
          onTap: () => _import(context, ref),
        ),
      ],
      appSection: [
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(context.l10n.templates),
          subtitle: Text(context.l10n.reusableTaskBlueprints),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const TemplatesPage())),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(context.l10n.trash),
          subtitle: Text(context.l10n.deletedTasksAreKeptFor),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const TrashPage())),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.widgets_outlined),
          title: Text(context.l10n.showDetailsOnTheHome),
          subtitle: Text(context.l10n.widgetDetailsBody),
          value: settings.widgetShowTasks,
          onChanged: settings.setWidgetShowTasks,
        ),
        if (settings.widgetShowTasks)
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(context.l10n.widgetShows),
            subtitle: Text(settings.widgetListId == null
                ? context.l10n.allLists
                : ref.watch(taskListProvider).byId(settings.widgetListId).name),
            onTap: () => _pickWidgetList(context, ref),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.showTaskDetailsInNotifications),
          subtitle: Text(context.l10n.offRemindersShowGenericText),
          value: settings.showTaskDetailsInNotifications,
          onChanged: settings.setShowTaskDetailsInNotifications,
        ),
      ],
    );
  }

  Future<void> _pickWidgetList(BuildContext context, WidgetRef ref) async {
    final lists = ref.read(taskListProvider).lists;
    final current = ref.read(settingsProvider).widgetListId;
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.widgetShows),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(current == null ? '${context.l10n.allLists}  ✓' : context.l10n.allLists),
          ),
          for (final l in lists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, l.id),
              child: Text(current == l.id ? '${l.name}  ✓' : l.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref.read(settingsProvider).setWidgetListId(picked.isEmpty ? null : picked);
  }

  Future<void> _saveExport(BuildContext context, WidgetRef ref, ZtExport export) async {
    final saved = await ref.read(vaultControllerProvider.notifier).whileShowingSystemUi(
          () => FilePicker.saveFile(fileName: export.fileName, bytes: export.zip),
        );
    if (saved != null && context.mounted) _snack(context, context.l10n.savedFile(export.fileName));
  }

  Future<void> _importGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref
          .read(vaultControllerProvider.notifier)
          .whileShowingSystemUi(() => FilePicker.pickFile(type: FileType.any));
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final lists = ref.read(taskListProvider);
      final parsed = const GoogleTasksImporter().parse(bytes, existingLists: lists.lists);
      if (!context.mounted) return;
      final manager = ref.read(taskManagerProvider);
      final preview = manager.previewImport(parsed.tasks);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.importFromGoogleTasks),
          content: Text([
            parsed.lists.isEmpty
                ? context.l10n.googleTasksFound(parsed.tasks.length)
                : context.l10n.googleTasksFoundInLists(parsed.tasks.length, parsed.lists.length),
            if (preview.toAdd > 0) context.l10n.willBeAdded(preview.toAdd),
            if (preview.toUpdate > 0) context.l10n.willBeUpdated(preview.toUpdate),
            if (preview.toAdd == 0 && preview.toUpdate == 0) context.l10n.everythingIsAlreadyHere,
            context.l10n.nothingIsUploadedToGoogle,
          ].join('\n\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.l10n.import)),
          ],
        ),
      );
      if (confirmed != true) return;
      final existingIds = lists.lists.map((l) => l.id).toSet();
      for (final list in parsed.lists) {
        if (!existingIds.contains(list.id)) await lists.save(list);
      }
      final written = await manager.importTasks(parsed.tasks);
      if (context.mounted) {
        _snack(context, written == 0 ? context.l10n.alreadyUpToDate : context.l10n.importedFromGoogle(written));
      }
    } on GoogleTasksImportException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } on Object catch (e) {
      if (context.mounted) _snack(context, context.l10n.importFailed(ztErrorMessage(e)));
    }
  }

  static void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static List<int>? _appKey(WidgetRef ref) => switch (ref.read(vaultControllerProvider)) {
        VaultUnlocked(:final appKey) => appKey,
        _ => null,
      };

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final key = _appKey(ref);
    if (key == null) return;
    try {
      final bytes = await BackupFileHelper.encode(ref.read(taskManagerProvider).tasks, key);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final saved = await ref.read(vaultControllerProvider.notifier).whileShowingSystemUi(
            () => FilePicker.saveFile(
              fileName: 'zero-trust-tasks-$stamp.${BackupFileHelper.extension}',
              bytes: bytes,
            ),
          );
      if (saved != null && context.mounted) _snack(context, context.l10n.backupFileSaved);
    } on Object catch (e) {
      if (context.mounted) _snack(context, context.l10n.exportFailed(ztErrorMessage(e)));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final key = _appKey(ref);
    if (key == null) return;
    try {
      final file = await ref
          .read(vaultControllerProvider.notifier)
          .whileShowingSystemUi(() => FilePicker.pickFile(type: FileType.any));
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final pepper = ref.read(legacyTasksPepperProvider);
      List<Task> tasks;
      try {
        tasks = await BackupFileHelper.decode(bytes, appKey: key, pepper: pepper);
      } on BackupNeedsPassword {
        if (!context.mounted) return;
        final password = await _askPassword(context);
        if (password == null) return;
        tasks = await BackupFileHelper.decode(
          bytes,
          appKey: key,
          password: password,
          pepper: pepper,
        );
      }
      if (!context.mounted) return;
      final manager = ref.read(taskManagerProvider);
      final confirmed = await RestorePreviewDialog.show(
        context,
        preview: manager.previewImport(tasks),
        confirmButtonLabel: context.l10n.import,
      );
      if (!confirmed) return;
      final written = await manager.importTasks(tasks);
      if (context.mounted) {
        _snack(context, written == 0 ? context.l10n.alreadyUpToDate : context.l10n.importedTasks(written));
      }
    } on Object catch (e) {
      if (context.mounted) {
        _snack(context, e is InvalidBackupFile ? e.message : context.l10n.importFailed(ztErrorMessage(e)));
      }
    }
  }

  static Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.backupFromAnEarlierVersion),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.l10n.passwordUsedWhenTheBackup,
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.open),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
