import 'package:flutter/material.dart';

/// Explains the app's zero-trust encryption model (item 16). Opened by
/// tapping the "Encryption: Active" badge.
class EncryptionInfoSheet extends StatelessWidget {
  const EncryptionInfoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Your data is encrypted',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.lock,
              title: 'AES-256-GCM encryption',
              description:
                  'Every task is encrypted on this device using AES-256-GCM '
                  'before it is ever saved or backed up.',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.key,
              title: 'Your master password never leaves this device',
              description:
                  'Your encryption key is derived from your master password '
                  'using PBKDF2 with 600,000 iterations. The password and '
                  'derived key are kept only in memory while the app is '
                  'unlocked.',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.cloud_off,
              title: 'The server never sees your tasks',
              description:
                  'Backups store only encrypted data. Without your master '
                  'password, nobody — including us — can read your tasks.',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.lock_clock,
              title: 'Locking the app',
              description:
                  'Closing or backgrounding the app clears the encryption '
                  'key from memory, so your tasks stay protected until you '
                  'unlock again.',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
