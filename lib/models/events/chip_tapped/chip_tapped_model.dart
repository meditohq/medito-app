import 'package:freezed_annotation/freezed_annotation.dart';
part 'chip_tapped_model.freezed.dart';
part 'chip_tapped_model.g.dart';

@freezed
abstract class ChipTappedModel with _$ChipTappedModel {
  const factory ChipTappedModel({
    required int chipId,
    required String chipTitle,
  }) = _ChipTappedModel;

  factory ChipTappedModel.fromJson(Map<String, Object?> json) =>
      _$ChipTappedModelFromJson(json);
}
