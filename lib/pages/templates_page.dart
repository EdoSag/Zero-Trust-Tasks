import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/globals/template_provider.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';
import 'package:zero_trust_tasks/models/task_template.dart';
import 'package:zero_trust_tasks/pages/add_task_screen.dart';

/// Displays saved [TaskTemplate]s and lets the user apply or delete them
/// (item 32).
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  @override
  void initState() {
    super.initState();
    TemplateProvider.of(context, listen: false).loadTemplates();
  }

  Future<void> _useTemplate(TaskTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(template: template),
      ),
    );
  }

  Future<void> _deleteTemplate(BuildContext context, TaskTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${template.title}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dCtx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await TemplateProvider.of(context, listen: false).removeTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = TemplateProvider.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.templates.isEmpty
              ? _EmptyState(onCreateTask: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTaskScreen(),
                    ),
                  ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.templates.length,
                  itemBuilder: (context, i) {
                    final template = provider.templates[i];
                    return _TemplateCard(
                      template: template,
                      onUse: () => _useTemplate(template),
                      onDelete: () => _deleteTemplate(context, template),
                    );
                  },
                ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onUse,
    required this.onDelete,
  });

  final TaskTemplate template;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete template',
                  color: theme.colorScheme.error,
                  onPressed: onDelete,
                ),
              ],
            ),
            if (template.description != null) ...[
              const SizedBox(height: 4),
              Text(
                template.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (template.category != null)
                  Chip(
                    label: Text(template.category!),
                    avatar: const Icon(Icons.label_outline, size: 14),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (template.subTaskTitles.isNotEmpty)
                  Chip(
                    label: Text('${template.subTaskTitles.length} sub-tasks'),
                    avatar: const Icon(Icons.checklist, size: 14),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (template.recurrence != null)
                  Chip(
                    label: Text(template.recurrence!.frequency.displayName),
                    avatar: const Icon(Icons.repeat, size: 14),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUse,
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('Use template'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTask});

  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No templates yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Open a task and use "Save as template" from the menu to create one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
