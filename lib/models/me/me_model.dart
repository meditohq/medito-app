import 'package:freezed_annotation/freezed_annotation.dart';

part 'me_model.freezed.dart';
part 'me_model.g.dart';

@freezed
abstract class MeModel with _$MeModel {
  const factory MeModel({
    String? email,
    required String id,
    @Default(false) bool hasActiveSubscription,
  }) = _MeModel;

  factory MeModel.fromJson(Map<String, Object?> json) =>
      _$MeModelFromJson(json);
}
