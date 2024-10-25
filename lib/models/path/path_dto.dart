import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_dto.freezed.dart';
part 'path_dto.g.dart';

@freezed
class PathDTO with _$PathDTO {
  const factory PathDTO({
    required List<StepDTO> steps,
  }) = _PathDTO;

  factory PathDTO.fromJson(Map<String, dynamic> json) => _$PathDTOFromJson(json);
}

@freezed
class StepDTO with _$StepDTO {
  const factory StepDTO({
    required String id,
    required String title,
    required List<TaskDTO> tasks,
    @Default(false) bool isUnlocked,
    @Default(false) bool isCompleted,
  }) = _StepDTO;

  factory StepDTO.fromJson(Map<String, dynamic> json) => _$StepDTOFromJson(json);
}

@freezed
class TaskDTO with _$TaskDTO {
  const factory TaskDTO({
    required String id,
    required String type,
    required String title,
    required bool isCompleted,
    required int lastUpdated,
    required Map<String, dynamic> data,
  }) = _TaskDTO;

  factory TaskDTO.fromJson(Map<String, dynamic> json) => _$TaskDTOFromJson(json);
}
