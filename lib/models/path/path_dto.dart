import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_dto.freezed.dart';
part 'path_dto.g.dart';

@freezed
class PathDTO with _$PathDTO {
  const factory PathDTO({
    required String id,
    required String title,
    required String description,
    required List<StepDTO> steps,
  }) = _PathDTO;

  factory PathDTO.fromJson(Map<String, dynamic> json) => _$PathDTOFromJson(json);
}

@freezed
class StepDTO with _$StepDTO {
  const factory StepDTO({
    required String id,
    required String title,
    required String description,
    @Default(true) bool isLocked,
    required List<TaskDTO> tasks,
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
    required String description,
    @Default(false) bool isRequired,
    @Default(false) bool isCompleted,
    int? lastUpdated,
    @Default({}) Map<String, dynamic> data,
  }) = _TaskDTO;

  factory TaskDTO.fromJson(Map<String, dynamic> json) => _$TaskDTOFromJson(json);
}
