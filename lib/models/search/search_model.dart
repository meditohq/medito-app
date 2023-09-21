import 'package:freezed_annotation/freezed_annotation.dart';
part 'search_model.freezed.dart';
part 'search_model.g.dart';

@freezed
abstract class SearchModel with _$SearchModel {
  const factory SearchModel({
    required String id,
    required String type,
    required String title,
    required String category,
    required String path,
    required String coverUrl,
  }) = _SearchModel;

  factory SearchModel.fromJson(Map<String, Object?> json) =>
      _$SearchModelFromJson(json);
}

