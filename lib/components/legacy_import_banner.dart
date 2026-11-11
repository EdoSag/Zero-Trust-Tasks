import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/legacy/legacy_tasks_import.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

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
              ? context.l10n.moved1ItemFromThe
              : context.l10n.movedItems(next.imported)),
        ));
      }
    });
    if (_dismissed) return const SizedBox.shrink();
    return switch (state) {
      LegacyImportNeedsPassword(:final wrongPassword) => MaterialBanner(
          leading: const Icon(Icons.move_down),
          content: Text(wrongPassword
              ? context.l10n.thatPasswordDidntOpenYour
              : context.l10n.yourTasksFromThePrevious),
          actions: [
            TextButton(onPressed: () => setState(() => _dismissed = true), child: Text(context.l10n.later)),
            FilledButton.tonal(
              onPressed: () => _askPassword(wrong: wrongPassword),
              child: Text(context.l10n.enterPassword),
            ),
          ],
        ),
      LegacyImportFailed(:final error) => MaterialBanner(
          leading: const Icon(Icons.cloud_off_outlined),
          content: Text(context.l10n.legacyFailed(ztErrorMessage(error))),
          actions: [
            TextButton(onPressed: () => setState(() => _dismissed = true), child: Text(context.l10n.later)),
            FilledButton.tonal(
              onPressed: () => ref.read(legacyTasksImportProvider.notifier).retry(),
              child: Text(context.l10n.tryAgain),
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
      title: Text(context.l10n.bringOverYourTasks),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.legacyExplain),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: context.l10n.password,
              errorText: widget.wrong ? context.l10n.tryThePasswordFromThe : null,
              suffixIcon: IconButton(
                tooltip: _obscure ? context.l10n.showPassword : context.l10n.hidePassword,
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.l10n.continueLabel),
        ),
      ],
    );
  }
}
