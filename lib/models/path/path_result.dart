import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_result.freezed.dart';

sealed class PathResult {}

class PathResultSuccess extends PathResult {
  final List<Step> steps;

  PathResultSuccess(this.steps);
}

class PathResultError extends PathResult {
  final String message;

  PathResultError(this.message);
}

@freezed
class Step with _$Step {
  const factory Step({
    required String id,
    required String title,
    required List<Task> tasks,
    @Default(false) bool isUnlocked,
    @Default(false) bool isCompleted,
  }) = _Step;
}

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required TaskType type,
    required String title,
    required bool isCompleted,
    required DateTime lastUpdated,
    required TaskData data,
  }) = _Task;
}

sealed class TaskData {}

class MeditationData extends TaskData {
  final int duration;

  MeditationData({required this.duration});
}

class JournalData extends TaskData {
  final String entryText;

  JournalData({required this.entryText});
}

class ArticleData extends TaskData {
  final String content;

  ArticleData({required this.content});
}

enum TaskType {
  meditation,
  journal,
  article,
}
