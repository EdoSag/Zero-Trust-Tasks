import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/models/task_template.dart';

/// Tasks are the app's default collection: items with no `kind`.
final tasksCollection = ZtCollection<Task>(
  kind: null,
  version: 1,
  fromJson: (id, json, _) => Task.fromJson(<String, dynamic>{...json, 'id': id}),
  toJson: (task) => task.toJson(),
  idOf: (task) => task.id,
);

/// Reusable task blueprints, synced like tasks.
final templatesCollection = ZtCollection<TaskTemplate>(
  kind: 'template',
  version: 1,
  fromJson: (id, json, _) => TaskTemplate.fromJson(<String, dynamic>{...json, 'id': id}),
  toJson: (template) => template.toJson(),
  idOf: (template) => template.id,
);
