import 'package:freezed_annotation/freezed_annotation.dart';
part 'menuItem_tapped_model.freezed.dart';
part 'menuItem_tapped_model.g.dart';

@freezed
abstract class MenuItemTappedModel with _$MenuItemTappedModel {
  const factory MenuItemTappedModel({
    required String name,
    required MenuItemTappedModel payload,
  }) = _MenuItemTappedModel;

  factory MenuItemTappedModel.fromJson(Map<String, Object?> json) =>
      _$MenuItemTappedModelFromJson(json);
}

@freezed
abstract class MenuItemTappedPayloadModel with _$MenuItemTappedPayloadModel {
  const factory MenuItemTappedPayloadModel({
    required int itemId,
    required String itemTitle,
  }) = _MenuItemTappedPayloadModel;

  factory MenuItemTappedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$MenuItemTappedPayloadModelFromJson(json);
}
