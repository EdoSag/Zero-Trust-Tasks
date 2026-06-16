import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/models/backup_preview.dart';

/// Shows a diff of what applying a backup would change, then requires the
/// user to type a confirmation phrase before proceeding (item 25).
class RestorePreviewDialog extends StatefulWidget {
  const RestorePreviewDialog({
    super.key,
    required this.preview,
    this.confirmPhrase = 'RESTORE',
    this.confirmButtonLabel = 'Restore',
  });

  final BackupPreview preview;
  final String confirmPhrase;
  final String confirmButtonLabel;

  /// Returns `true` if the user confirmed after reviewing the preview.
  static Future<bool> show(
    BuildContext context, {
    required BackupPreview preview,
    String confirmPhrase = 'RESTORE',
    String confirmButtonLabel = 'Restore',
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
      title: const Text('Review backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This backup contains ${preview.backupTaskCount} task${preview.backupTaskCount == 1 ? '' : 's'}. '
              'Applying it will make the following changes:',
            ),
            const SizedBox(height: 12),
            _ChangeRow(
              icon: Icons.add_circle_outline,
              color: Colors.green,
              label: '${preview.toAdd} task${preview.toAdd == 1 ? '' : 's'} added',
            ),
            _ChangeRow(
              icon: Icons.edit_outlined,
              color: theme.colorScheme.primary,
              label: '${preview.toUpdate} task${preview.toUpdate == 1 ? '' : 's'} updated',
            ),
            _ChangeRow(
              icon: Icons.remove_circle_outline,
              color: theme.colorScheme.error,
              label: '${preview.toRemove} task${preview.toRemove == 1 ? '' : 's'} removed',
            ),
            if (!preview.hasChanges) ...[
              const SizedBox(height: 8),
              Text(
                'Your local data is already up to date.',
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
                  const TextSpan(text: 'Type '),
                  TextSpan(
                    text: widget.confirmPhrase,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' to confirm.'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isMatch ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(widget.confirmButtonLabel),
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
