import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/backup_preview.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Shows a diff of what applying a backup would change, then requires the
/// user to type a confirmation phrase before proceeding (item 25).
class RestorePreviewDialog extends StatefulWidget {
  const RestorePreviewDialog({
    super.key,
    required this.preview,
    this.confirmPhrase = 'RESTORE',
    this.confirmButtonLabel,
  });

  final BackupPreview preview;
  final String confirmPhrase;
  final String? confirmButtonLabel;

  /// Returns `true` if the user confirmed after reviewing the preview.
  static Future<bool> show(
    BuildContext context, {
    required BackupPreview preview,
    String confirmPhrase = 'RESTORE',
    String? confirmButtonLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RestorePreviewDialog(
        preview: preview,
        confirmPhrase: confirmPhrase,
        confirmButtonLabel: confirmButtonLabel,
      ),
    );
    return result ?? false;
  }

  @override
  State<RestorePreviewDialog> createState() => _RestorePreviewDialogState();
}

class _RestorePreviewDialogState extends State<RestorePreviewDialog> {
  final _controller = TextEditingController();
  bool _isMatch = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isMatch = _controller.text == widget.confirmPhrase;
      if (isMatch != _isMatch) setState(() => _isMatch = isMatch);
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
    final preview = widget.preview;

    return AlertDialog(
      title: Text(context.l10n.reviewBackup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.backupContains(preview.backupTaskCount),
            ),
            const SizedBox(height: 12),
            _ChangeRow(
              icon: Icons.add_circle_outline,
              color: Colors.green,
              label: context.l10n.tasksAdded(preview.toAdd),
            ),
            _ChangeRow(
              icon: Icons.edit_outlined,
              color: theme.colorScheme.primary,
              label: context.l10n.tasksUpdated(preview.toUpdate),
            ),
            _ChangeRow(
              icon: Icons.remove_circle_outline,
              color: theme.colorScheme.error,
              label: context.l10n.tasksRemoved(preview.toRemove),
            ),
            if (!preview.hasChanges) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.yourLocalDataIsAlready,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isMatch ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(widget.confirmButtonLabel ?? context.l10n.restore),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
