import 'package:freezed_annotation/freezed_annotation.dart';

part 'end_screen_model.freezed.dart';
part 'end_screen_model.g.dart';

@freezed
abstract class EndScreenModel with _$EndScreenModel {
  const factory EndScreenModel({
    required String name,
    required int position,
    required EndScreenContentModel content,
  }) = _EndScreenModel;

  factory EndScreenModel.fromJson(Map<String, Object?> json) =>
      _$EndScreenModelFromJson(json);
}

@freezed
abstract class EndScreenContentModel with _$EndScreenContentModel {
  const factory EndScreenContentModel({
    String? id,
    String? title,
    String? text,
    String? ctaPath,
    String? ctaTitle,
    String? colorBackground,
    String? colorText,
    String? ctaType,
    List<EndScreenOptionsModel>? options,
  }) = _EndScreenContentModel;

  factory EndScreenContentModel.fromJson(Map<String, Object?> json) =>
      _$EndScreenContentModelFromJson(json);
}

@freezed
abstract class EndScreenOptionsModel with _$EndScreenOptionsModel {
  const factory EndScreenOptionsModel({
    required String value,
  }) = _EndScreenOptionsModel;

  factory EndScreenOptionsModel.fromJson(Map<String, Object?> json) =>
      _$EndScreenOptionsModelFromJson(json);
}
