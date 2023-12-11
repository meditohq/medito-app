import 'package:freezed_annotation/freezed_annotation.dart';

part 'menuItem_tapped_model.freezed.dart';
part 'menuItem_tapped_model.g.dart';

@freezed
abstract class MenuItemTappedModel with _$MenuItemTappedModel {
  const factory MenuItemTappedModel({
    required String itemId,
    required String itemTitle,
  }) = _MenuItemTappedModel;

  factory MenuItemTappedModel.fromJson(Map<String, Object?> json) =>
      _$MenuItemTappedModelFromJson(json);
}
