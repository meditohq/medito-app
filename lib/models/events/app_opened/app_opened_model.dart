import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_opened_model.freezed.dart';
part 'app_opened_model.g.dart';

@freezed
abstract class AppOpenedModel with _$AppOpenedModel {
  const factory AppOpenedModel({
    required String deviceOs,
    required String deviceLanguage,
    required String deviceModel,
    required String buildNumber,
    required String appVersion,
  }) = _AppOpenedModel;

  factory AppOpenedModel.fromJson(Map<String, Object?> json) =>
      _$AppOpenedModelFromJson(json);
}
