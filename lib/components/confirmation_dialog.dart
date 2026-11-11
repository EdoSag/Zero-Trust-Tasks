import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// A dialog for high-impact destructive actions (cloud restore, permanent
/// delete) that requires the user to type a confirmation phrase before the
/// action button becomes enabled (item 5).
class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmPhrase,
    this.confirmButtonLabel,
    this.isDestructive = true,
  });

  final String title;
  final String message;

  /// The exact text the user must type to enable the confirm button.
  final String confirmPhrase;
  final String? confirmButtonLabel;
  final bool isDestructive;

  /// Shows the dialog and returns `true` if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmPhrase,
    String? confirmButtonLabel,
    bool isDestructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmPhrase: confirmPhrase,
        confirmButtonLabel: confirmButtonLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  State<ConfirmationDialog> createState() {
    return _ConfirmationDialogState();
  }
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isMatch = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isMatch = _controller.text == widget.confirmPhrase;
      if (isMatch != _isMatch) {
        setState(() {
          _isMatch = isMatch;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(text: context.l10n.typePrefix),
                TextSpan(
                  text: widget.confirmPhrase,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: context.l10n.toConfirmSuffix),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.confirmPhrase,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isMatch ? () => Navigator.pop(context, true) : null,
          style: widget.isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          child: Text(widget.confirmButtonLabel ?? context.l10n.confirm),
        ),
      ],
    );
  }
}
