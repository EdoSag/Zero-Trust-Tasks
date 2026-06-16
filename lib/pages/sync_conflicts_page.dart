import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/conflict_resolution.dart';
import 'package:zero_trust_tasks/models/sync_conflict.dart';

/// Shows all sync conflicts and lets the user resolve each one (item 36).
class SyncConflictsPage extends StatefulWidget {
  const SyncConflictsPage({super.key, required this.conflicts});

  final List<SyncConflict> conflicts;

  @override
  State<SyncConflictsPage> createState() => _SyncConflictsPageState();
}

class _SyncConflictsPageState extends State<SyncConflictsPage> {
  final _resolved = <int>{};
  bool _isBusy = false;

  Future<void> _resolve(int index, ConflictResolution resolution) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await TaskManager.of(context).resolveConflict(
        widget.conflicts[index],
        resolution,
      );
      setState(() => _resolved.add(index));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
    if (mounted && _resolved.length == widget.conflicts.length) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Conflicts (${widget.conflicts.length})'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.conflicts.length,
        itemBuilder: (context, i) {
          final conflict = widget.conflicts[i];
          final isResolved = _resolved.contains(i);
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isResolved ? Icons.check_circle : Icons.sync_problem,
                        color: isResolved
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          conflict.local.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (isResolved) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Resolved',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                  ] else ...[
                    const Divider(height: 20),
                    _VersionRow(
                      label: 'Your device',
                      icon: Icons.smartphone,
                      updatedAt: dateFormat.format(conflict.local.updatedAt),
                      isCompleted: conflict.local.isCompleted,
                    ),
                    const SizedBox(height: 8),
                    _VersionRow(
                      label: 'Cloud',
                      icon: Icons.cloud_outlined,
                      updatedAt: dateFormat.format(conflict.remote.updatedAt),
                      isCompleted: conflict.remote.isCompleted,
                    ),
                    const SizedBox(height: 16),
                    if (_isBusy)
                      const Center(child: CircularProgressIndicator())
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _resolve(i, ConflictResolution.keepLocal),
                            icon: const Icon(Icons.smartphone, size: 16),
                            label: const Text('Keep device'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _resolve(i, ConflictResolution.keepRemote),
                            icon: const Icon(Icons.cloud_download_outlined,
                                size: 16),
                            label: const Text('Keep cloud'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _resolve(i, ConflictResolution.keepBoth),
                            icon: const Icon(Icons.call_split, size: 16),
                            label: const Text('Keep both'),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.icon,
    required this.updatedAt,
    required this.isCompleted,
  });

  final String label;
  final IconData icon;
  final String updatedAt;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          'Modified $updatedAt',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 8),
        if (isCompleted)
          Icon(Icons.check_circle_outline,
              size: 14, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}
