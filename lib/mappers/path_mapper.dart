import '../models/path/path_dto.dart';
import '../models/path/path_result.dart';

class PathMapper {
  PathResult mapDtoToResult(PathDTO dto) {
    try {
      var steps = dto.steps.map((stepDto) => _mapStepDtoToStep(stepDto)).toList();
      return PathResultSuccess(steps);
    } catch (e) {
      return PathResultError('Failed to map path data: ${e.toString()}');
    }
  }

  Step _mapStepDtoToStep(StepDTO dto) {
    var tasks = dto.tasks.map((taskDto) => _mapTaskDtoToTask(taskDto)).toList();
    return Step(
      id: dto.id,
      title: dto.title,
      tasks: tasks,
      isUnlocked: dto.isUnlocked,
      isCompleted: dto.isCompleted, 
    );
  }

  Task _mapTaskDtoToTask(TaskDTO dto) {
    return Task(
      id: dto.id,
      type: _mapStringToTaskType(dto.type),
      title: dto.title,
      isCompleted: dto.isCompleted,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(dto.lastUpdated),
      data: _mapTaskData(dto.type, dto.data),
    );
  }

  TaskType _mapStringToTaskType(String type) {
    switch (type) {
      case 'meditation':
        return TaskType.meditation;
      case 'journal':
        return TaskType.journal;
      case 'article':
        return TaskType.article;
      default:
        throw ArgumentError('Unknown task type: $type');
    }
  }

  TaskData _mapTaskData(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'meditation':
        return MeditationData(duration: data['duration'] as int);
      case 'journal':
        return JournalData(entryText: data['entryText'] as String);
      case 'article':
        return ArticleData(content: data['content'] as String);
      default:
        throw ArgumentError('Unknown task type: $type');
    }
  }
}
