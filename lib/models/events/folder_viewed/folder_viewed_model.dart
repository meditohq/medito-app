import 'package:freezed_annotation/freezed_annotation.dart';
part 'folder_viewed_model.freezed.dart';
part 'folder_viewed_model.g.dart';

@freezed
abstract class FolderViewedModel with _$FolderViewedModel {
  const factory FolderViewedModel({
    required String name,
    required FolderViewedModel payload,
  }) = _FolderViewedModel;

  factory FolderViewedModel.fromJson(Map<String, Object?> json) =>
      _$FolderViewedModelFromJson(json);
}

@freezed
abstract class FolderViewedPayloadModel with _$FolderViewedPayloadModel {
  const factory FolderViewedPayloadModel({
    required int folderId,
  }) = _FolderViewedPayloadModel;

  factory FolderViewedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$FolderViewedPayloadModelFromJson(json);
}
