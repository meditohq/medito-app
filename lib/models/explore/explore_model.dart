import 'package:freezed_annotation/freezed_annotation.dart';

part 'explore_model.freezed.dart';
part 'explore_model.g.dart';

@freezed
abstract class ExploreModel with _$ExploreModel {
  const factory ExploreModel({
    String? message,
    @Default(<ExploreItemsModel>[]) List<ExploreItemsModel> items,
  }) = _ExploreModel;

  factory ExploreModel.fromJson(Map<String, Object?> json) =>
      _$ExploreModelFromJson(json);
}

@freezed
abstract class ExploreItemsModel with _$ExploreItemsModel {
  const factory ExploreItemsModel({
    required String id,
    required String type,
    required String title,
    required String category,
    required String path,
    required String coverUrl,
  }) = _ExploreItemsModel;

  factory ExploreItemsModel.fromJson(Map<String, Object?> json) =>
      _$ExploreItemsModelFromJson(json);
}
