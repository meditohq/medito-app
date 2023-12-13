import 'package:freezed_annotation/freezed_annotation.dart';

part 'me_model.freezed.dart';
part 'me_model.g.dart';

@freezed
abstract class MeModel with _$MeModel {
  const factory MeModel({
    required String id,
    String? email,
  }) = _MeModel;

  factory MeModel.fromJson(Map<String, Object?> json) =>
      _$MeModelFromJson(json);
}
