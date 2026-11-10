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
          title: const Text('Import from Google Tasks'),
          subtitle: const Text('Your Google Takeout .zip or Tasks.json'),
          onTap: () => _importGoogle(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Export backup file'),
          subtitle: const Text('Encrypted; only your account can open it'),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Import backup file'),
          subtitle: const Text('Adds tasks from a .ztasks file, including older versions\''),
          onTap: () => _import(context, ref),
        ),
      ],
      appSection: [
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('Templates'),
          subtitle: const Text('Reusable task blueprints'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const TemplatesPage())),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Trash'),
          subtitle: const Text('Deleted tasks are kept for 30 days'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const TrashPage())),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.widgets_outlined),
          title: const Text('Show details on the home screen'),
          subtitle: const Text(
            'Off: the widget shows counts only. On: the titles of your next tasks are '
            'stored unencrypted on this phone for the home screen, so anyone holding '
            'the unlocked phone can see them',
          ),
          value: settings.widgetShowTasks,
          onChanged: settings.setWidgetShowTasks,
        ),
        if (settings.widgetShowTasks)
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Widget shows'),
            subtitle: Text(settings.widgetListId == null
                ? 'All lists'
                : ref.watch(taskListProvider).byId(settings.widgetListId).name),
            onTap: () => _pickWidgetList(context, ref),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Show task details in notifications'),
          subtitle: const Text('Off: reminders show generic text only (recommended)'),
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
        title: const Text('Widget shows'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Text(current == null ? 'All lists  ✓' : 'All lists'),
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
    if (saved != null && context.mounted) _snack(context, 'Saved ${export.fileName}');
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
          title: const Text('Import from Google Tasks'),
          content: Text([
            '${parsed.tasks.length} tasks found'
                '${parsed.lists.isEmpty ? '' : ' in ${parsed.lists.length} new ${parsed.lists.length == 1 ? 'list' : 'lists'}'}.',
            if (preview.toAdd > 0) '${preview.toAdd} will be added.',
            if (preview.toUpdate > 0) '${preview.toUpdate} already here will be updated.',
            if (preview.toAdd == 0 && preview.toUpdate == 0) 'Everything is already here.',
            'Nothing is uploaded to Google; your tasks are encrypted on this phone.',
          ].join('\n\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Import')),
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
        _snack(context, written == 0 ? 'Already up to date' : 'Imported $written tasks from Google Tasks');
      }
    } on GoogleTasksImportException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } on Object catch (e) {
      if (context.mounted) _snack(context, 'Import failed: ${ztErrorMessage(e)}');
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
      if (saved != null && context.mounted) _snack(context, 'Backup file saved');
    } on Object catch (e) {
      if (context.mounted) _snack(context, 'Export failed: ${ztErrorMessage(e)}');
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
        confirmButtonLabel: 'Import',
      );
      if (!confirmed) return;
      final written = await manager.importTasks(tasks);
      if (context.mounted) {
        _snack(context, written == 0 ? 'Already up to date' : 'Imported $written tasks');
      }
    } on Object catch (e) {
      if (context.mounted) {
        _snack(context, e is InvalidBackupFile ? e.message : 'Import failed: ${ztErrorMessage(e)}');
      }
    }
  }

  static Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup from an earlier version'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password used when the backup was made',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
