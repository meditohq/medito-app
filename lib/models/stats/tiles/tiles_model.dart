import 'package:freezed_annotation/freezed_annotation.dart';

part 'tiles_model.freezed.dart';
part 'tiles_model.g.dart';

@freezed
abstract class TilesModel with _$TilesModel {
  const factory TilesModel({
    required String icon,
    required String color,
    required String title,
    required String subtitle,
  }) = _TilesModel;

  factory TilesModel.fromJson(Map<String, Object?> json) =>
      _$TilesModelFromJson(json);
}
