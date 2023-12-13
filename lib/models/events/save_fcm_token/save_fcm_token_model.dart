import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_fcm_token_model.freezed.dart';
part 'save_fcm_token_model.g.dart';

@freezed
abstract class SaveFcmTokenModel with _$SaveFcmTokenModel {
  const factory SaveFcmTokenModel({
    required String fcmToken,
  }) = _SaveFcmTokenModel;

  factory SaveFcmTokenModel.fromJson(Map<String, Object?> json) =>
      _$SaveFcmTokenModelFromJson(json);
}
