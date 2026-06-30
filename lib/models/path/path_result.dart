import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_result.freezed.dart';

sealed class JourneyResult {}

class JourneyResultSuccess extends JourneyResult {
  final List<JourneyStep> steps;

  JourneyResultSuccess(this.steps);
}

class PathResultError extends JourneyResult {
  final String message;

  PathResultError.journeyResultError(this.message);
}

@freezed
abstract class JourneyStep with _$JourneyStep {
  const factory JourneyStep({
    required String id,
    required String title,
    required List<Task> tasks,
    @Default(false) bool isLocked,
    @Default(false) bool isCompleted,
  }) = _Step;
}

@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required TaskType type,
    required String title,
    required bool isCompleted,
    required DateTime lastUpdated,
    required TaskData data,
    @Default(true) bool isRequired,
  }) = _Task;
}

sealed class TaskData {
  final String id;

  TaskData({required this.id});
}

class TrackData extends TaskData {
  final int duration;

  TrackData({required this.duration, required super.id});
}

class JournalData extends TaskData {
  final String entryText;

  JournalData({required this.entryText, required super.id});
}

class ArticleData extends TaskData {
  final String content;

  ArticleData({required this.content, required super.id});
}

enum TaskType { track, journal, article }

class TaskUpdate {
  final String stepId;
  final String taskId;
  final List<int> completedAt;
  final Map<String, dynamic> data;

  TaskUpdate({
    required this.stepId,
    required this.taskId,
    required this.completedAt,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
    'step_id': stepId,
    'task_id': taskId,
    'completed_at': completedAt,
    'data': data,
  };
}

class TaskUpdatePayload {
  final String? id;
  final int? updated;
  final List<TaskUpdate> tasks;

  TaskUpdatePayload({this.id, this.updated, required this.tasks});

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (updated != null) 'updated': updated,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
}
