import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_chips_items_model.freezed.dart';
part 'home_chips_items_model.g.dart';

@freezed
abstract class HomeChipsItemsModel with _$HomeChipsItemsModel {
  const factory HomeChipsItemsModel({
    required String id,
    required String type,
    required String title,
    required String path,
  }) = _HomeChipsItemsModel;

  factory HomeChipsItemsModel.fromJson(Map<String, Object?> json) =>
      _$HomeChipsItemsModelFromJson(json);
}
