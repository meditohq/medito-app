import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_rows_model.freezed.dart';
part 'home_rows_model.g.dart';

@freezed
abstract class HomeRowsModel with _$HomeRowsModel {
  const factory HomeRowsModel({
    required String title,
    @Default(<HomeRowItemsModel>[]) List<HomeRowItemsModel> items,
  }) = _HomeRowsModel;

  factory HomeRowsModel.fromJson(Map<String, Object?> json) =>
      _$HomeRowsModelFromJson(json);
}

@freezed
abstract class HomeRowItemsModel with _$HomeRowItemsModel {
  const factory HomeRowItemsModel({
    required String id,
    required String type,
    required String title,
    required String path,
    required String coverUrl,
  }) = _HomeRowItemsModel;

  factory HomeRowItemsModel.fromJson(Map<String, Object?> json) =>
      _$HomeRowItemsModelFromJson(json);
}
