import 'package:json_annotation/json_annotation.dart';

part 'token_dto.g.dart';

@JsonSerializable()
class TokenDTO {
  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  @JsonKey(name: 'expires_in')
  final int expiresIn;

  @JsonKey(name: 'client_id')
  final String clientId;

  final String? email;

  TokenDTO({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.clientId,
    this.email,
  });

  factory TokenDTO.fromJson(Map<String, dynamic> json) =>
      _$TokenDTOFromJson(json);

  Map<String, dynamic> toJson() => _$TokenDTOToJson(this);
}

// Token response after refresh (lacks refresh token and other fields)
@JsonSerializable()
class RefreshTokenDTO {
  @JsonKey(name: 'access_token')
  final String accessToken;

  @JsonKey(name: 'expires_in')
  final int expiresIn;

  RefreshTokenDTO({required this.accessToken, required this.expiresIn});

  factory RefreshTokenDTO.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenDTOFromJson(json);

  Map<String, dynamic> toJson() => _$RefreshTokenDTOToJson(this);
}
