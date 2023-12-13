import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_token_model.freezed.dart';
part 'user_token_model.g.dart';

@freezed
abstract class UserTokenModel with _$UserTokenModel {
  const factory UserTokenModel({
    String? email,
    required String id,
    required String token,
  }) = _UserTokenModel;

  factory UserTokenModel.fromJson(Map<String, Object?> json) =>
      _$UserTokenModelFromJson(json);
}
