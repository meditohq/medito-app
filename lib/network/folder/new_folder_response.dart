import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_folder_response.freezed.dart';
part 'new_folder_response.g.dart';

@freezed
class NewFolderResponse with _$NewFolderResponse {
  const factory NewFolderResponse({
    required Data? data,
  }) = _NewFolderResponse;

  factory NewFolderResponse.fromJson(Map<String, Object?> json) =>
      _$NewFolderResponseFromJson(json);
}

@freezed
class Data with _$Data {
  const factory Data(
      {int? id,
      String? title,
      String? subtitle,
      String? description,
      List<FolderItem>? items}) = _Data;

  factory Data.fromJson(Map<String, Object?> json) => _$DataFromJson(json);
}

@freezed
class FolderItem with _$FolderItem {
  const factory FolderItem({
    Item? item,
  }) = _FolderItem;

  factory FolderItem.fromJson(Map<String, Object?> json) =>
      _$FolderItemFromJson(json);
}

@freezed
class Item with _$Item {
  const factory Item({int? id, String? type, String? title, String? subtitle}) =
      _Item;

  factory Item.fromJson(Map<String, Object?> json) => _$ItemFromJson(json);
}
