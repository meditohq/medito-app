import 'package:freezed_annotation/freezed_annotation.dart';
part 'background_sounds_model.freezed.dart';
part 'background_sounds_model.g.dart';

@freezed
abstract class BackgroundSoundsModel with _$BackgroundSoundsModel {
  const factory BackgroundSoundsModel({
    required int id,
    required String name,
    required String path,
    required int duration,
  }) = _BackgroundSoundsModel;

  factory BackgroundSoundsModel.fromJson(Map<String, Object?> json) =>
      _$BackgroundSoundsModelFromJson(json);
}
