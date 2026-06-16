import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/models/sub_task.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

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

  DateTime? _dueDate;

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
      _dueDate = task.dueDate;
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
    for (final controller in _subTaskControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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
        dueDate: _dueDate,
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
        dueDate: _dueDate,
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
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _dueDate == null
                    ? 'No due date'
                    : 'Due: ${_dueDate?.toString().split(' ')[0]}',
              ),
              trailing: _dueDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear due date',
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                    ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _dueDate = date;
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
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
