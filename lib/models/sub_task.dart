import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class SubTask {
  SubTask({required this.id, required this.title, this.isCompleted = false});

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  final String id;

  final String title;

  final bool isCompleted;

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  SubTask copyWith({String? id, String? title, bool? isCompleted}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
