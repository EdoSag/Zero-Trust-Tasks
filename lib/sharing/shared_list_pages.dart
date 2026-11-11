import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/globals/providers.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/task_list.dart';
import 'package:zero_trust_tasks/sharing/shared_lists.dart';

/// The app id in invite links (`zt1.tasks.…`).
const String tasksInviteApp = 'tasks';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
}

/// The name other people see: asked once, remembered in the vault.
Future<String?> askSharingName(BuildContext context, WidgetRef ref, {required String title}) async {
  final current = await ref.read(sharedListsProvider.notifier).sharingName();
  if (!context.mounted) return null;
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: current),
  );
  if (name == null || name.trim().isEmpty) return null;
  await ref.read(sharedListsProvider.notifier).saveSharingName(name.trim());
  return name.trim();
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.sharingExplain),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.yourName, helperText: l.yourNameHint),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(onPressed: _submit, child: Text(l.continueLabel)),
      ],
    );
  }
}

/// Turns the account's own [list] into a shared list: its tasks move into a
/// new shared space with this account as owner, then the invite page opens.
Future<void> shareList(BuildContext context, WidgetRef ref, TaskList list) async {
  final l = context.l10n;
  final manager = ref.read(taskManagerProvider);
  final tasks = manager.tasks.where((t) => (t.listId ?? TaskList.defaultId) == list.id).toList();
  final name = await askSharingName(context, ref, title: l.shareListQ(list.name));
  if (name == null || !context.mounted) return;
  final controller = ref.read(sharedListsProvider.notifier);
  final lists = ref.read(taskListProvider);
  final String spaceId;
  try {
    spaceId = await controller.create(list, myName: name, tasks: tasks);
  } on Object {
    if (context.mounted) _snack(context, l.sharingNeedsInternet);
    return;
  }
  // The shared copy is saved; the account's own copy goes.
  await manager.dropPrivateCopies(tasks.map((t) => t.id));
  if (!list.isDefault) await lists.remove(list.id);
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SharedListPage(spaceId: spaceId, inviteNow: true)));
}

/// A new, empty shared list.
Future<String?> newSharedList(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final listName = await showDialog<String>(context: context, builder: (_) => _ListNameDialog());
  if (listName == null || !context.mounted) return null;
  final name = await askSharingName(context, ref, title: l.newSharedList);
  if (name == null || !context.mounted) return null;
  try {
    final spaceId = await ref.read(sharedListsProvider.notifier).create(TaskList.create(name: listName), myName: name);
    if (context.mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => SharedListPage(spaceId: spaceId, inviteNow: true)));
    }
    return TaskList.sharedId(spaceId);
  } on Object {
    if (context.mounted) _snack(context, l.sharingNeedsInternet);
    return null;
  }
}

class _ListNameDialog extends StatefulWidget {
  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.newSharedList),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: context.l10n.listName),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      TextButton(onPressed: _submit, child: Text(context.l10n.continueLabel)),
    ],
  );
}

/// One shared list: who is in it, people waiting to join, inviting, and
/// leaving or deleting it.
class SharedListPage extends ConsumerStatefulWidget {
  const SharedListPage({super.key, required this.spaceId, this.inviteNow = false});

  final String spaceId;

  /// Opens the invite right away (just shared).
  final bool inviteNow;

  @override
  ConsumerState<SharedListPage> createState() => _SharedListPageState();
}

class _SharedListPageState extends ConsumerState<SharedListPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.inviteNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _invite();
      });
    }
  }

  TaskList? get _list {
    for (final l in ref.read(sharedListsProvider).lists) {
      if (l.shared!.spaceId == widget.spaceId) return l;
    }
    return null;
  }

  Future<void> _invite() async {
    final list = _list;
    if (list == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvitePage(spaceId: widget.spaceId, listName: list.name),
      ),
    );
    ref.invalidate(pendingJoinsProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      if (mounted) _snack(context, context.l10n.sharingNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _memberOptions(SpaceMember m, TaskList list) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(m.role == SpaceRole.admin ? l.makeMember : l.makeOwner),
              onTap: () => Navigator.pop(ctx, 'role'),
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: Theme.of(ctx).colorScheme.error),
              title: Text(l.removeFromList, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final spaces = ref.read(ztSpacesProvider.notifier);
    if (choice == 'role') {
      await _run(
        () => spaces.setRole(widget.spaceId, m.userId, m.role == SpaceRole.admin ? SpaceRole.member : SpaceRole.admin),
      );
    } else if (choice == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.removeQ(m.name)),
          content: Text(l.removeExplain(list.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.removeFromList)),
          ],
        ),
      );
      if (ok == true) await _run(() => spaces.remove(widget.spaceId, m.userId));
    }
    await ref.read(sharedListsProvider.notifier).reload();
  }

  Future<void> _leaveOrDelete(TaskList list, {required bool delete}) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(delete ? l.deleteSharedListQ(list.name) : l.leaveListQ(list.name)),
        content: Text(delete ? l.deleteSharedListExplain : l.leaveListExplain),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(delete ? l.deleteForEveryone : l.leaveList),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final controller = ref.read(sharedListsProvider.notifier);
    final navigator = Navigator.of(context);
    await _run(() => delete ? controller.deleteForEveryone(widget.spaceId) : controller.leave(widget.spaceId));
    if (mounted && _list == null) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(sharedListsProvider);
    TaskList? list;
    for (final x in state.lists) {
      if (x.shared!.spaceId == widget.spaceId) list = x;
    }
    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.sharedListGone)),
      );
    }
    final info = list.shared!;
    final joins = [
      for (final j in ref.watch(pendingJoinsProvider).value ?? const <PendingJoin>[])
        if (j.spaceId == widget.spaceId) j,
    ];
    final me = info.myUserId;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(info.waiting ? l.waitingToJoin : list.name),
        actions: [
          IconButton(
            tooltip: l.syncNow,
            icon: const Icon(Icons.sync),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await ref.read(ztSpacesProvider.notifier).refresh();
                    await ref.read(ztSpacesProvider.notifier).syncNow(widget.spaceId);
                    ref.invalidate(pendingJoinsProvider);
                  }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (info.waiting) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top, size: 48),
                  const SizedBox(height: 16),
                  Text(l.waitingExplain, textAlign: TextAlign.center),
                  if (info.joinCode != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      info.joinCode!,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 3),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l.sharedListE2e, style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final j in joins)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.person_add_alt),
                  title: Text(l.joinRequest(j.name)),
                  subtitle: Text(l.joinRequestHint),
                  onTap: () => confirmJoin(context, ref, j, listName: list!.name),
                ),
              ),
            ListTile(title: Text(l.peopleInList(info.members.length), style: Theme.of(context).textTheme.titleSmall)),
            for (final m in info.members)
              ListTile(
                leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase())),
                title: Text(m.userId == me ? l.youName(m.name) : m.name),
                subtitle: Text(m.role == SpaceRole.admin ? l.owner : l.member),
                trailing: info.isAdmin && m.userId != me ? const Icon(Icons.more_vert) : null,
                onTap: info.isAdmin && m.userId != me && !_busy ? () => _memberOptions(m, list!) : null,
              ),
            if (info.isAdmin)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _invite,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(l.invitePeople),
                ),
              ),
          ],
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(l.leaveList, style: TextStyle(color: scheme.error)),
            enabled: !_busy,
            onTap: () => _leaveOrDelete(list!, delete: false),
          ),
          if (info.isAdmin)
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
              title: Text(l.deleteForEveryone, style: TextStyle(color: scheme.error)),
              enabled: !_busy,
              onTap: () => _leaveOrDelete(list!, delete: true),
            ),
        ],
      ),
    );
  }
}

/// A link (and QR code) for one person to join a shared list.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key, required this.spaceId, required this.listName});
  final String spaceId;
  final String listName;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  SpaceInviteLink? _link;
  bool _busy = false;
  bool _asOwner = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final link = await ref
          .read(ztSpacesProvider.notifier)
          .invite(widget.spaceId, role: _asOwner ? SpaceRole.admin : SpaceRole.member);
      if (mounted) setState(() => _link = link);
    } on Object {
      if (mounted) _snack(context, context.l10n.sharingNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = _link;
    final joins = [
      for (final j in ref.watch(pendingJoinsProvider).value ?? const <PendingJoin>[])
        if (j.spaceId == widget.spaceId) j,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTo(widget.listName))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final j in joins)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(l.joinRequest(j.name)),
                subtitle: Text(l.joinRequestHint),
                onTap: () => confirmJoin(context, ref, j, listName: widget.listName),
              ),
            ),
          if (link == null) ...[
            Text(l.inviteIntro),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.inviteAsOwner),
              subtitle: Text(l.inviteAsOwnerHint),
              value: _asOwner,
              onChanged: (v) => setState(() => _asOwner = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.qr_code),
              label: Text(l.createInvite),
            ),
          ] else ...[
            Text(l.inviteReady, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: link.qrData, size: 240, semanticsLabel: l.inviteQr),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link.toString()));
                      if (context.mounted) _snack(context, l.linkCopied);
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l.copyLink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: l.inviteMessage(widget.listName, link.toString()))),
                    icon: const Icon(Icons.share),
                    label: Text(l.shareLink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.inviteNextSteps, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => ref.invalidate(pendingJoinsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l.checkForAnswers),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The owner compares the code on the other person's phone, then lets
/// them in.
Future<void> confirmJoin(BuildContext context, WidgetRef ref, PendingJoin j, {required String listName}) async {
  final l = context.l10n;
  final spaces = ref.read(ztSpacesProvider.notifier);
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.confirmJoinTitle(j.name, listName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.confirmJoinBody),
          const SizedBox(height: 16),
          Text(
            j.verificationCode,
            textDirection: TextDirection.ltr,
            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'reject'), child: Text(l.codesDiffer)),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.later)),
        TextButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: Text(l.codesMatch)),
      ],
    ),
  );
  try {
    if (choice == 'ok') {
      await spaces.confirm(j);
      if (context.mounted) _snack(context, l.joined(j.name));
    } else if (choice == 'reject') {
      await spaces.revokeInvite(j.inviteId);
    } else {
      return;
    }
  } on Object {
    if (context.mounted) _snack(context, l.sharingNeedsInternet);
  }
  ref.invalidate(pendingJoinsProvider);
  await ref.read(sharedListsProvider.notifier).reload();
}

/// Joins a shared list from an invite link (pasted, scanned, or opened from
/// a message), then shows the code to compare with the owner.
class JoinListPage extends ConsumerStatefulWidget {
  const JoinListPage({super.key, this.initialLink});
  final String? initialLink;

  @override
  ConsumerState<JoinListPage> createState() => _JoinListPageState();
}

class _JoinListPageState extends ConsumerState<JoinListPage> {
  late final _link = TextEditingController(text: widget.initialLink);
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _code;

  @override
  void initState() {
    super.initState();
    ref
        .read(sharedListsProvider.notifier)
        .sharingName()
        .then((name) {
          if (mounted && _name.text.isEmpty) _name.text = name;
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validLink(String? v) {
    try {
      final link = SpaceInviteLink.parse(v ?? '');
      if (link.app != tasksInviteApp) return context.l10n.inviteOtherApp;
      return null;
    } on FormatException {
      return context.l10n.inviteInvalid;
    }
  }

  Future<void> _scan() async {
    final text = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (text != null) setState(() => _link.text = text);
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      final lists = ref.read(sharedListsProvider.notifier);
      await lists.saveSharingName(name);
      final started = await ref.read(ztSpacesProvider.notifier).answer(SpaceInviteLink.parse(_link.text), myName: name);
      await lists.reload();
      if (mounted) setState(() => _code = started.verificationCode);
    } on SpaceRefused {
      if (mounted) _snack(context, l.inviteUsed);
    } on Object {
      if (mounted) _snack(context, l.sharingNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: Text(l.joinSharedList)),
      body: code != null
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.verified_user_outlined, size: 56),
                const SizedBox(height: 16),
                Text(l.joinCodeTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  code,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 16),
                Text(l.joinCodeBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.done)),
              ],
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l.joinIntro),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _link,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.inviteLink,
                      suffixIcon: IconButton(
                        tooltip: l.scanQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      ),
                    ),
                    validator: _validLink,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l.yourName, helperText: l.yourNameHint),
                    validator: (v) => v == null || v.trim().isEmpty ? l.nameRequired : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _busy ? null : _join, child: Text(l.join)),
                ],
              ),
            ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _key = GlobalKey(debugLabel: 'qr');
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.scanQr)),
    body: QRView(
      key: _key,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).colorScheme.primary,
        borderRadius: 12,
        borderLength: 32,
        borderWidth: 8,
        cutOutSize: 260,
      ),
      onQRViewCreated: (controller) {
        controller.scannedDataStream.listen((b) {
          final code = b.code;
          if (_done || code == null) return;
          try {
            SpaceInviteLink.parse(code);
          } on FormatException {
            return;
          }
          _done = true;
          controller.pauseCamera();
          if (context.mounted) Navigator.of(context).pop(code);
        });
      },
    ),
  );
}

/// Under the list chips: who a shared list is shared with, and people
/// waiting to join any list this account owns.
class SharedListStrip extends ConsumerWidget {
  const SharedListStrip({super.key, required this.scope});
  final TaskListScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(sharedListsProvider);
    if (state.lists.isEmpty) return const SizedBox.shrink();
    final joins = ref.watch(pendingJoinsProvider).value ?? const <PendingJoin>[];
    final spaceId = TaskList.spaceIdOf(scope.listId);
    TaskList? current;
    for (final x in state.lists) {
      if (x.shared!.spaceId == spaceId) current = x;
    }
    String nameOf(String id) {
      for (final x in state.lists) {
        if (x.shared!.spaceId == id) return x.name;
      }
      return '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final j in joins)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_add_alt),
              title: Text(l.joinRequestFor(j.name, nameOf(j.spaceId))),
              subtitle: Text(l.joinRequestHint),
              onTap: () => confirmJoin(context, ref, j, listName: nameOf(j.spaceId)),
            ),
          ),
        if (current != null)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
            leading: const Icon(Icons.group_outlined),
            title: Text(
              current.shared!.waiting
                  ? l.waitingToJoin
                  : l.sharedWith(current.shared!.members.map((m) => m.name).join(', ')),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SharedListPage(spaceId: spaceId!))),
          ),
      ],
    );
  }
}
