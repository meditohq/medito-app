import '../models/path/path_dto.dart';
import '../models/path/path_result.dart';
import '../utils/logger.dart';

class PathMapper {
  JourneyResult mapDtoToResult(PathDTO dto) {
    try {
      var steps =
          dto.steps.map((stepDto) => _mapStepDtoToStep(stepDto)).toList();
      return JourneyResultSuccess(steps);
    } catch (e) {
      AppLogger.d('PATH', e.toString());
      return PathResultError.journeyResultError(
          'Failed to map path data: ${e.toString()}');
    }
  }

  JourneyStep _mapStepDtoToStep(StepDTO dto) {
    var tasks = dto.tasks.map((taskDto) => _mapTaskDtoToTask(taskDto)).toList();
    return JourneyStep(
      id: dto.id,
      title: dto.title,
      tasks: tasks,
      isLocked: dto.isLocked,
      isCompleted: dto.isCompleted,
    );
  }

  Task _mapTaskDtoToTask(TaskDTO dto) {
    return Task(
      id: dto.id,
      type: _mapStringToTaskType(dto.type),
      title: dto.title,
      isCompleted: dto.isCompleted,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(dto.lastUpdated ?? 0),
      data: _mapTaskData(dto.id, dto.type, dto.data),
      isRequired: dto.isRequired,
    );
  }

  TaskType _mapStringToTaskType(String type) {
    switch (type) {
      case 'track':
        return TaskType.track;
      case 'journal':
        return TaskType.journal;
      case 'article':
        return TaskType.article;
      default:
        throw ArgumentError('Unknown task type: $type');
    }
  }

  TaskData _mapTaskData(String id, String type, Map<String, dynamic> data) {
    switch (type) {
      case 'track':
        var trackId = data['track_id'] as String? ?? '';
        var duration = data['duration'] as int? ?? 0;

        return TrackData(id: trackId, duration: duration);
      case 'journal':
        var entryText = data['entryText'] as String? ?? '';

        return JournalData(id: id, entryText: entryText);
      case 'article':
        var content = data['content'] as String? ?? '';

        return ArticleData(id: id, content: content);
      default:
        throw ArgumentError('Unknown task type: $type');
    }
  }
}
