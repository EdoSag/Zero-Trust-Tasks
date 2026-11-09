import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_import.dart';

/// Shows how the one-time move of tasks from the earlier app version is
/// going, and asks for the password on a device that doesn't have the old
/// key. Hidden when there is nothing to say.
class LegacyImportBanner extends ConsumerStatefulWidget {
  const LegacyImportBanner({super.key});

  @override
  ConsumerState<LegacyImportBanner> createState() => _LegacyImportBannerState();
}

class _LegacyImportBannerState extends ConsumerState<LegacyImportBanner> {
  bool _dismissed = false;
  int? _shownDoneFor;

  Future<void> _askPassword({bool wrong = false}) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(wrong: wrong),
    );
    if (password == null || password.isEmpty || !mounted) return;
    await ref.read(legacyTasksImportProvider.notifier).submitPassword(password);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legacyTasksImportProvider);
    ref.listen(legacyTasksImportProvider, (_, next) {
      if (next is LegacyImportDone && next.imported > 0 && _shownDoneFor != next.imported) {
        _shownDoneFor = next.imported;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.imported == 1
              ? 'Moved 1 item from the previous version'
              : 'Moved ${next.imported} items from the previous version'),
        ));
      }
    });
    if (_dismissed) return const SizedBox.shrink();
    return switch (state) {
      LegacyImportNeedsPassword(:final wrongPassword) => MaterialBanner(
          leading: const Icon(Icons.move_down),
          content: Text(wrongPassword
              ? 'That password didn\'t open your earlier tasks. Use the password you had in the previous version of the app.'
              : 'Your tasks from the previous version are ready to move over. Enter your password once to bring them here.'),
          actions: [
            TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Later')),
            FilledButton.tonal(
              onPressed: () => _askPassword(wrong: wrongPassword),
              child: const Text('Enter password'),
            ),
          ],
        ),
      LegacyImportFailed(:final error) => MaterialBanner(
          leading: const Icon(Icons.cloud_off_outlined),
          content: Text('Couldn\'t bring over your tasks from the previous version yet. '
              '${ztErrorMessage(error)}'),
          actions: [
            TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Later')),
            FilledButton.tonal(
              onPressed: () => ref.read(legacyTasksImportProvider.notifier).retry(),
              child: const Text('Try again'),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.wrong});
  final bool wrong;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bring over your tasks'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your earlier tasks were encrypted with your password. '
              'It is used on this phone only, to open them once.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: widget.wrong ? 'Try the password from the previous version' : null,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
