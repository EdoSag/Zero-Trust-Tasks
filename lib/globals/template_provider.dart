import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/models/task_template.dart';

/// Saved [TaskTemplate]s, synced and encrypted like tasks (see
/// `templatesCollection`).
class TemplateProvider extends ChangeNotifier {
  List<TaskTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<TaskTemplate>>? _subscription;
  Future<void> Function(TaskTemplate)? _save;
  Future<void> Function(String)? _delete;
  bool _disposed = false;

  List<TaskTemplate> get templates => List.unmodifiable(_templates);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void attach({
    Stream<List<TaskTemplate>>? source,
    Future<void> Function(TaskTemplate)? save,
    Future<void> Function(String)? delete,
  }) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _save = save;
    _delete = delete;
    _templates = [];
    _isLoading = source != null;
    _error = null;
    _notify();
    _subscription = source?.listen(
      (templates) {
        _templates = templates..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        _isLoading = false;
        _notify();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = ztErrorMessage(e);
        _notify();
      },
    );
  }

  Future<void> addTemplate(TaskTemplate template) async {
    final save = _save ?? (throw StateError('Your tasks are locked.'));
    _templates = [..._templates, template];
    _notify();
    await save(template);
  }

  Future<void> removeTemplate(String id) async {
    final delete = _delete ?? (throw StateError('Your tasks are locked.'));
    _templates = _templates.where((t) => t.id != id).toList();
    _notify();
    await delete(id);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
