import 'package:freezed_annotation/freezed_annotation.dart';
part 'folder_model.freezed.dart';
part 'folder_model.g.dart';

@freezed
abstract class FolderModel with _$FolderModel {
  const factory FolderModel(
      {required int id,
      required String title,
      required String description,
      required String coverUrl,
      required bool isPublished,
      @Default([]) List<FolderItemsModel> items}) = _FolderModel;

  factory FolderModel.fromJson(Map<String, Object?> json) =>
      _$FolderModelFromJson(json);

  

}

@freezed
abstract class FolderItemsModel with _$FolderItemsModel {
  const factory FolderItemsModel(
      {required String type,
      required int id,
      required String title,
      required String subtitle,
      required String path}) = _FolderItemsModel;

  factory FolderItemsModel.fromJson(Map<String, Object?> json) =>
      _$FolderItemsModelFromJson(json);
}
