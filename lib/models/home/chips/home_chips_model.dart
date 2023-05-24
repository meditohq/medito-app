import 'package:freezed_annotation/freezed_annotation.dart';
part 'home_chips_model.freezed.dart';
part 'home_chips_model.g.dart';

@freezed
abstract class HomeChipsModel with _$HomeChipsModel {
  const factory HomeChipsModel({
    @Default(<HomeChipsItemsModel>[]) List<HomeChipsItemsModel> line1,
    @Default(<HomeChipsItemsModel>[]) List<HomeChipsItemsModel> line2,
  }) = _HomeChipsModel;

  factory HomeChipsModel.fromJson(Map<String, Object?> json) =>
      _$HomeChipsModelFromJson(json);
}

@freezed
abstract class HomeChipsItemsModel with _$HomeChipsItemsModel {
  const factory HomeChipsItemsModel({
    required String type,
    required String label,
    required String path,
  }) = _HomeChipsItemsModel;

  factory HomeChipsItemsModel.fromJson(Map<String, Object?> json) =>
      _$HomeChipsItemsModelFromJson(json);
}
