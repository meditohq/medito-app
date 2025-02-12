import 'package:freezed_annotation/freezed_annotation.dart';

part 'pack_model.freezed.dart';
part 'pack_model.g.dart';

@Freezed(makeCollectionsUnmodifiable: false)
class PackModel with _$PackModel {
  const factory PackModel({
    required String id,
    required String title,
    String? subtitle,
    String? coverUrl,
    required String path,
    String? description,
    @Default(false) bool isPublished,
    @Default(<PackItemsModel>[]) List<PackItemsModel> items,
  }) = _PackModel;

  factory PackModel.fromJson(Map<String, dynamic> json) =>
      _$PackModelFromJson(json);
}

@Freezed(makeCollectionsUnmodifiable: false)
class PackItemsModel with _$PackItemsModel {
  const factory PackItemsModel({
    required String type,
    required String id,
    required String title,
    String? subtitle,
    String? coverUrl,
    required String path,
    bool? isCompleted,
  }) = _PackItemsModel;

  factory PackItemsModel.fromJson(Map<String, dynamic> json) =>
      _$PackItemsModelFromJson(json);
}
