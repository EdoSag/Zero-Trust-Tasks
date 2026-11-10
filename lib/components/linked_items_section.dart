import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/suite/linked_app_launcher.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';
import 'package:zero_trust_tasks/suite/linked_items.dart';

/// The notes (ZT Notes) and people (ZT Contacts) linked to a task, with
/// buttons to link more. Used on the task page and in the editor.
///
/// The other apps' data is only loaded once a task has a link or the user
/// opens a picker.
class LinkedItemsSection extends ConsumerWidget {
  const LinkedItemsSection({
    required this.noteIds,
    required this.contactIds,
    required this.onChanged,
    super.key,
  });

  final List<String> noteIds;
  final List<String> contactIds;
  final void Function(List<String> noteIds, List<String> contactIds) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notes = noteIds.isEmpty ? null : ref.watch(linkedNotesProvider);
    final contacts = contactIds.isEmpty ? null : ref.watch(linkedContactsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked notes and contacts',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        for (final id in noteIds)
          _LinkedTile(
            key: ValueKey('note-$id'),
            icon: Icons.sticky_note_2_outlined,
            item: notes,
            find: (List<LinkedNote> all) => all.where((n) => n.id == id).firstOrNull,
            title: (n) => n.displayTitle,
            subtitle: (n) => n.preview,
            missing: 'Note not found. It may have been deleted in ZT Notes.',
            onTap: (n) => _showNote(context, n),
            onRemove: () => onChanged([...noteIds]..remove(id), contactIds),
          ),
        for (final id in contactIds)
          _LinkedTile(
            key: ValueKey('contact-$id'),
            icon: Icons.person_outline,
            item: contacts,
            find: (List<LinkedContact> all) => all.where((c) => c.id == id).firstOrNull,
            title: (c) => c.name,
            subtitle: (c) => c.detail,
            missing: 'Contact not found. It may have been deleted in ZT Contacts.',
            onTap: (c) => _showContact(context, c),
            onRemove: () => onChanged(noteIds, [...contactIds]..remove(id)),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.sticky_note_2_outlined, size: 18),
              label: const Text('Link a note'),
              onPressed: () async {
                final picked = await showLinkPicker<LinkedNote>(
                  context,
                  app: LinkedApp.notes,
                  provider: linkedNotesProvider,
                  selected: noteIds,
                  idOf: (n) => n.id,
                  titleOf: (n) => n.displayTitle,
                  subtitleOf: (n) => n.preview,
                  icon: Icons.sticky_note_2_outlined,
                );
                if (picked != null) onChanged(picked, contactIds);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Link a contact'),
              onPressed: () async {
                final picked = await showLinkPicker<LinkedContact>(
                  context,
                  app: LinkedApp.contacts,
                  provider: linkedContactsProvider,
                  selected: contactIds,
                  idOf: (c) => c.id,
                  titleOf: (c) => c.name,
                  subtitleOf: (c) => c.detail,
                  icon: Icons.person_outline,
                );
                if (picked != null) onChanged(noteIds, picked);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkedTile<T> extends StatelessWidget {
  const _LinkedTile({
    required this.icon,
    required this.item,
    required this.find,
    required this.title,
    required this.subtitle,
    required this.missing,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final IconData icon;
  final AsyncValue<List<T>>? item;
  final T? Function(List<T>) find;
  final String Function(T) title;
  final String Function(T) subtitle;
  final String missing;
  final void Function(T) onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final all = item;
    final found = all?.value == null ? null : find(all!.value as List<T>);
    final String text;
    String? sub;
    if (found != null) {
      text = title(found);
      final s = subtitle(found);
      sub = s.isEmpty ? null : s;
    } else if (all is AsyncError) {
      text = 'Couldn\'t load this link';
      sub = ztErrorMessage((all as AsyncError).error);
    } else if (all == null || all.isLoading) {
      text = 'Loading…';
    } else {
      text = missing;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: sub == null ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: found == null ? null : () => onTap(found),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: 'Remove link',
        onPressed: onRemove,
      ),
    );
  }
}

void _showNote(BuildContext context, LinkedNote note) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(note.displayTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SelectableText(note.body.trim().isEmpty ? 'This note is empty.' : note.body.trim()),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open ZT Notes'),
              onPressed: () => openLinkedApp(LinkedApp.notes),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showContact(BuildContext context, LinkedContact contact) {
  Future<void> open(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object {
      // Reported below.
    }
    messenger.showSnackBar(const SnackBar(content: Text('No app on this phone can do that.')));
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final phone in contact.phones) ...[
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: Text('Call $phone'),
              onTap: () => open(Uri(scheme: 'tel', path: phone)),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text('Text $phone'),
              onTap: () => open(Uri(scheme: 'sms', path: phone)),
            ),
          ],
          for (final email in contact.emails)
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text('Email $email'),
              onTap: () => open(Uri(scheme: 'mailto', path: email)),
            ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open ZT Contacts'),
            onTap: () => openLinkedApp(LinkedApp.contacts),
          ),
        ],
      ),
    ),
  );
}

/// A searchable list of the account's notes or contacts with tick boxes.
/// Returns the chosen ids, or null when dismissed.
Future<List<String>?> showLinkPicker<T>(
  BuildContext context, {
  required LinkedApp app,
  required ProviderListenable<AsyncValue<List<T>>> provider,
  required List<String> selected,
  required String Function(T) idOf,
  required String Function(T) titleOf,
  required String Function(T) subtitleOf,
  required IconData icon,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LinkPicker<T>(
      app: app,
      provider: provider,
      selected: selected,
      idOf: idOf,
      titleOf: titleOf,
      subtitleOf: subtitleOf,
      icon: icon,
    ),
  );
}

class _LinkPicker<T> extends ConsumerStatefulWidget {
  const _LinkPicker({
    required this.app,
    required this.provider,
    required this.selected,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
    required this.icon,
  });

  final LinkedApp app;
  final ProviderListenable<AsyncValue<List<T>>> provider;
  final List<String> selected;
  final String Function(T) idOf;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final IconData icon;

  @override
  ConsumerState<_LinkPicker<T>> createState() => _LinkPickerState<T>();
}

class _LinkPickerState<T> extends ConsumerState<_LinkPicker<T>> {
  late final List<String> _picked = [...widget.selected];
  String _query = '';

  bool get _isNotes => widget.app == LinkedApp.notes;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(widget.provider);
    final theme = Theme.of(context);
    final what = _isNotes ? 'notes' : 'contacts';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_isNotes ? 'Link notes' : 'Link contacts', style: theme.textTheme.titleLarge),
                  ),
                  FilledButton(
                    // The app theme makes filled buttons full width; not in a row.
                    style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
                    onPressed: () => Navigator.pop(context, _picked),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search $what',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (items) {
                AsyncData(:final value) => _list(value),
                AsyncError(:final error) => _message(
                    'Couldn\'t load your $what. ${ztErrorMessage(error)}',
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {bool offerApp = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (offerApp) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open ${widget.app.label}'),
                  onPressed: () => openLinkedApp(widget.app),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _list(List<T> all) {
    if (all.isEmpty) {
      return _message(
        _isNotes
            ? 'No notes yet. Notes you write in ZT Notes with this account show up here.'
            : 'No contacts yet. People you save in ZT Contacts with this account show up here.',
        offerApp: true,
      );
    }
    final shown = _query.isEmpty
        ? all
        : all
            .where((i) =>
                widget.titleOf(i).toLowerCase().contains(_query) ||
                widget.subtitleOf(i).toLowerCase().contains(_query))
            .toList();
    if (shown.isEmpty) return _message('Nothing matches "$_query".');
    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final item = shown[index];
        final id = widget.idOf(item);
        final sub = widget.subtitleOf(item);
        return CheckboxListTile(
          value: _picked.contains(id),
          secondary: Icon(widget.icon),
          title: Text(widget.titleOf(item), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
          onChanged: (on) => setState(() => on == true ? _picked.add(id) : _picked.remove(id)),
        );
      },
    );
  }
}
