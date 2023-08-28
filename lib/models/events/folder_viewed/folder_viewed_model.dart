import 'package:freezed_annotation/freezed_annotation.dart';
part 'folder_viewed_model.freezed.dart';
part 'folder_viewed_model.g.dart';

@freezed
abstract class FolderViewedModel with _$FolderViewedModel {
  const factory FolderViewedModel({
    required String folderId,
  }) = _FolderViewedModel;

  factory FolderViewedModel.fromJson(Map<String, Object?> json) =>
      _$FolderViewedModelFromJson(json);
}
