import 'package:freezed_annotation/freezed_annotation.dart';
part 'search_model.freezed.dart';
part 'search_model.g.dart';

@freezed
abstract class SearchModel with _$SearchModel {
  const factory SearchModel({
    String? message,
    @Default(<SearchItemsModel>[]) List<SearchItemsModel> items,
  }) = _SearchModel;

  factory SearchModel.fromJson(Map<String, Object?> json) =>
      _$SearchModelFromJson(json);
}

@freezed
abstract class SearchItemsModel with _$SearchItemsModel {
  const factory SearchItemsModel({
    required String id,
    required String type,
    required String title,
    required String category,
    required String path,
    required String coverUrl,
  }) = _SearchItemsModel;

  factory SearchItemsModel.fromJson(Map<String, Object?> json) =>
      _$SearchItemsModelFromJson(json);
}
