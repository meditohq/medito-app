import 'package:Medito/routes/routes.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'join_route_params_model.freezed.dart';
part 'join_route_params_model.g.dart';

@freezed
abstract class JoinRouteParamsModel with _$JoinRouteParamsModel {
  const factory JoinRouteParamsModel({
    required Screen screen,
    String? email,
  }) = _JoinRouteParamsModel;

  factory JoinRouteParamsModel.fromJson(Map<String, Object?> json) =>
      _$JoinRouteParamsModelFromJson(json);
}
