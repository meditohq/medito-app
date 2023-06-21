import 'package:freezed_annotation/freezed_annotation.dart';
part 'chip_tapped_model.freezed.dart';
part 'chip_tapped_model.g.dart';

@freezed
abstract class ChipTappedModel with _$ChipTappedModel {
  const factory ChipTappedModel({
    required String name,
    required ChipTappedModel payload,
  }) = _ChipTappedModel;

  factory ChipTappedModel.fromJson(Map<String, Object?> json) =>
      _$ChipTappedModelFromJson(json);
}

@freezed
abstract class ChipTappedPayloadModel with _$ChipTappedPayloadModel {
  const factory ChipTappedPayloadModel({
    required int chipId,
    required String chipTitle,
  }) = _ChipTappedPayloadModel;

  factory ChipTappedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$ChipTappedPayloadModelFromJson(json);
}
