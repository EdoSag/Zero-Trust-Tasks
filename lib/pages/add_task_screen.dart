import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';
import 'package:zero_trust_tasks/core/services/notification_service.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';

@NowaGenerated()
class AddTaskScreen extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const AddTaskScreen({super.key, this.taskToEdit});

  final Task? taskToEdit;

  @override
  State<AddTaskScreen> createState() {
    return _AddTaskScreenState();
  }
}

@NowaGenerated()
class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _categoryController = TextEditingController();

  TextEditingController? _categoryAutocompleteController;

  TaskPriority _selectedPriority = TaskPriority.medium;

  DateTime? _startDate;

  DateTime? _dueDate;

  TimeOfDay? _dueTime;

  DateTime? _reminderAt;

  List<String> _tags = [];

  final _notesController = TextEditingController();

  final _tagInputController = TextEditingController();

  final _linkUrlController = TextEditingController();

  List<String> _links = [];

  RecurrenceFrequency? _recurrenceFrequency;
  int _recurrenceInterval = 1;
  List<int> _recurrenceWeekdays = [];
  DateTime? _recurrenceEndDate;

  List<SubTask> _subTasks = [];

  final Map<String, TextEditingController> _subTaskControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit;
      _titleController.text = task!.title;
      _descriptionController.text = task.description ?? '';
      _categoryController.text = task.category ?? '';
      _selectedPriority = task.priority;
      _startDate = task.startDate;
      _dueDate = task.dueDate;
      if (task.dueDate != null) {
        _dueTime = TimeOfDay.fromDateTime(task.dueDate!);
      }
      _reminderAt = task.reminderAt;
      _tags = List.of(task.tags);
      _notesController.text = task.notes ?? '';
      _links = List.of(task.links);
      if (task.recurrence != null) {
        _recurrenceFrequency = task.recurrence!.frequency;
        _recurrenceInterval = task.recurrence!.interval;
        _recurrenceWeekdays = List.of(task.recurrence!.weekdays ?? []);
        _recurrenceEndDate = task.recurrence!.endDate;
      }
      _subTasks = List.of(task.subTasks);
    }
    for (final subTask in _subTasks) {
      _subTaskControllers[subTask.id] = TextEditingController(
        text: subTask.title,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    _linkUrlController.dispose();
    for (final controller in _subTaskControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final recurrenceRule = _recurrenceFrequency == null
        ? null
        : RecurrenceRule(
            frequency: _recurrenceFrequency!,
            interval: _recurrenceInterval,
            weekdays: _recurrenceFrequency == RecurrenceFrequency.weekly &&
                    _recurrenceWeekdays.isNotEmpty
                ? List.of(_recurrenceWeekdays)
                : null,
            endDate: _recurrenceEndDate,
          );
    // Merge due time into due date if both are set.
    DateTime? effectiveDueDate = _dueDate;
    if (effectiveDueDate != null && _dueTime != null) {
      effectiveDueDate = DateTime(
        effectiveDueDate.year,
        effectiveDueDate.month,
        effectiveDueDate.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );
    }
    final effectiveNotes =
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final taskManager = TaskManager.of(context);
    final finalSubTasks = _subTasks
        .map(
          (subTask) => subTask.copyWith(
            title: _subTaskControllers[subTask.id]?.text.trim() ??
                subTask.title,
          ),
        )
        .toList();
    if (widget.taskToEdit != null) {
      final updatedTask = widget.taskToEdit!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        priority: _selectedPriority,
        startDate: _startDate,
        clearStartDate: _startDate == null,
        dueDate: effectiveDueDate,
        clearDueDate: effectiveDueDate == null,
        reminderAt: _reminderAt,
        recurrence: recurrenceRule,
        clearRecurrence: recurrenceRule == null,
        tags: _tags,
        notes: effectiveNotes,
        clearNotes: effectiveNotes == null,
        links: _links,
        subTasks: finalSubTasks,
      );
      await taskManager.updateTask(updatedTask);
    } else {
      final newTask = Task.create(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        priority: _selectedPriority,
        startDate: _startDate,
        dueDate: effectiveDueDate,
        reminderAt: _reminderAt,
        recurrence: recurrenceRule,
        tags: _tags,
        notes: effectiveNotes,
        links: _links,
        subTasks: finalSubTasks,
      );
      await taskManager.addTask(newTask);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _addSubTask() {
    setState(() {
      final subTask = SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
      );
      _subTasks.add(subTask);
      _subTaskControllers[subTask.id] = TextEditingController();
    });
  }

  void _removeSubTask(String subTaskId) {
    setState(() {
      _subTasks.removeWhere((s) => s.id == subTaskId);
      _subTaskControllers.remove(subTaskId)?.dispose();
    });
  }

  void _toggleSubTaskComplete(String subTaskId, bool? value) {
    setState(() {
      final index = _subTasks.indexWhere((s) => s.id == subTaskId);
      if (index != -1) {
        _subTasks[index] = _subTasks[index].copyWith(
          isCompleted: value ?? false,
        );
      }
    });
  }

  void _reorderSubTasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final subTask = _subTasks.removeAt(oldIndex);
      _subTasks.insert(newIndex, subTask);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskManager = TaskManager.of(context);
    final categories = taskManager.getCategories().whereType<String>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit != null ? 'Edit Task' : 'New Task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoryController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return categories;
                }
                final query = textEditingValue.text.toLowerCase();
                return categories.where(
                  (category) => category.toLowerCase().contains(query),
                );
              },
              onSelected: (selection) {
                _categoryController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (_categoryAutocompleteController != controller) {
                  _categoryAutocompleteController = controller;
                  controller.text = _categoryController.text;
                  controller.addListener(() {
                    _categoryController.text = controller.text;
                  });
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              items: TaskPriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            priority.icon,
                            size: 16,
                            color: priority.getColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(priority.displayName),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(
                _startDate == null
                    ? 'No start date'
                    : 'Start: ${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: _startDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear start date',
                      onPressed: () => setState(() => _startDate = null),
                    ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _startDate = date);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _dueDate == null
                    ? 'No due date'
                    : _dueTime == null
                        ? 'Due: ${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                        : 'Due: ${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')} ${_dueTime!.format(context)}',
              ),
              trailing: _dueDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                      }),
                    ),
              onTap: () async {
                final ctx = context;
                final date = await showDatePicker(
                  context: ctx,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(
                  context: ctx,
                  initialTime: _dueTime ?? TimeOfDay.now(),
                );
                setState(() {
                  _dueDate = date;
                  _dueTime = time;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                _reminderAt == null
                    ? 'No reminder'
                    : 'Remind: ${_reminderAt!.year}-${_reminderAt!.month.toString().padLeft(2, '0')}-${_reminderAt!.day.toString().padLeft(2, '0')} ${_reminderAt!.hour.toString().padLeft(2, '0')}:${_reminderAt!.minute.toString().padLeft(2, '0')}',
              ),
              trailing: _reminderAt == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear reminder',
                      onPressed: () {
                        setState(() {
                          _reminderAt = null;
                        });
                      },
                    ),
              onTap: () async {
                final ctx = context;
                final date = await showDatePicker(
                  context: ctx,
                  initialDate: _reminderAt ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(
                  context: ctx,
                  initialTime: _reminderAt != null
                      ? TimeOfDay.fromDateTime(_reminderAt!)
                      : TimeOfDay.now(),
                );
                if (time == null) return;
                final combined = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                setState(() {
                  _reminderAt = combined;
                });
                await NotificationService.instance.requestPermissions();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency?>(
              initialValue: _recurrenceFrequency,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.repeat),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No repeat')),
                ...RecurrenceFrequency.values.map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _recurrenceFrequency = value;
                  if (value == null) {
                    _recurrenceWeekdays = [];
                    _recurrenceEndDate = null;
                    _recurrenceInterval = 1;
                  }
                  if (value != RecurrenceFrequency.weekly) {
                    _recurrenceWeekdays = [];
                  }
                });
              },
            ),
            if (_recurrenceFrequency != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Every'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: _recurrenceInterval.toString(),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) {
                          setState(() => _recurrenceInterval = n);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _recurrenceFrequency == RecurrenceFrequency.daily
                        ? (_recurrenceInterval == 1 ? 'day' : 'days')
                        : _recurrenceFrequency == RecurrenceFrequency.weekly
                            ? (_recurrenceInterval == 1 ? 'week' : 'weeks')
                            : _recurrenceFrequency == RecurrenceFrequency.monthly
                                ? (_recurrenceInterval == 1 ? 'month' : 'months')
                                : (_recurrenceInterval == 1 ? 'year' : 'years'),
                  ),
                ],
              ),
              if (_recurrenceFrequency == RecurrenceFrequency.weekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {
                      1: 'Mon',
                      2: 'Tue',
                      3: 'Wed',
                      4: 'Thu',
                      5: 'Fri',
                      6: 'Sat',
                      7: 'Sun',
                    }.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _recurrenceWeekdays.contains(entry.key),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _recurrenceWeekdays.add(entry.key);
                            } else {
                              _recurrenceWeekdays.remove(entry.key);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(
                  _recurrenceEndDate == null
                      ? 'No end date'
                      : 'Ends: ${_recurrenceEndDate!.year}-${_recurrenceEndDate!.month.toString().padLeft(2, '0')}-${_recurrenceEndDate!.day.toString().padLeft(2, '0')}',
                ),
                trailing: _recurrenceEndDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear end date',
                        onPressed: () =>
                            setState(() => _recurrenceEndDate = null),
                      ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _recurrenceEndDate ??
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _recurrenceEndDate = date);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Tags
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagInputController,
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                      isDense: true,
                    ),
                    onFieldSubmitted: (value) {
                      final tag = value.trim();
                      if (tag.isNotEmpty && !_tags.contains(tag)) {
                        setState(() {
                          _tags.add(tag);
                          _tagInputController.clear();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add tag',
                  onPressed: () {
                    final tag = _tagInputController.text.trim();
                    if (tag.isNotEmpty && !_tags.contains(tag)) {
                      setState(() {
                        _tags.add(tag);
                        _tagInputController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 16),
            // Links
            if (_links.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: _links
                      .map(
                        (link) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link, size: 20),
                          title: Text(
                            link,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove link',
                            onPressed: () => setState(() => _links.remove(link)),
                          ),
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _linkUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Add link (URL)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_link),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    onFieldSubmitted: (value) {
                      final link = value.trim();
                      if (link.isNotEmpty && !_links.contains(link)) {
                        setState(() {
                          _links.add(link);
                          _linkUrlController.clear();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sub-tasks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addSubTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_subTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No sub-tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subTasks.length,
                onReorder: _reorderSubTasks,
                itemBuilder: (context, index) {
                  final subTask = _subTasks[index];
                  return Card(
                    key: ValueKey(subTask.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Checkbox(
                        value: subTask.isCompleted,
                        onChanged: (value) =>
                            _toggleSubTaskComplete(subTask.id, value),
                      ),
                      title: TextFormField(
                        controller: _subTaskControllers[subTask.id],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Sub-task title',
                        ),
                        style: TextStyle(
                          decoration: subTask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete sub-task',
                            onPressed: () => _removeSubTask(subTask.id),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _saveTask,
          icon: const Icon(Icons.save),
          label: Text(widget.taskToEdit != null ? 'Update Task' : 'Save Task'),
        ),
      ),
    );
  }
}
