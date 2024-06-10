import 'package:freezed_annotation/freezed_annotation.dart';

part 'pack_model.freezed.dart';
part 'pack_model.g.dart';

@Freezed(makeCollectionsUnmodifiable: false)
abstract class PackModel with _$PackModel {
  const factory PackModel({
    required String id,
    required String title,
    required String description,
    required String coverUrl,
    required bool isPublished,
    @Default(<PackItemsModel>[]) List<PackItemsModel> items,
  }) = _PackModel;

  factory PackModel.fromJson(Map<String, Object?> json) =>
      _$PackModelFromJson(json);
}

@Freezed(makeCollectionsUnmodifiable: false)
abstract class PackItemsModel with _$PackItemsModel {
  const factory PackItemsModel({
    required String type,
    required String id,
    required String title,
    String? subtitle,
    String? coverUrl,
    required String path,
    bool? isCompleted,
  }) = _PackItemsModel;

  factory PackItemsModel.fromJson(Map<String, Object?> json) =>
      _$PackItemsModelFromJson(json);
}
