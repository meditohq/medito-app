import 'package:freezed_annotation/freezed_annotation.dart';

part 'editorial_model.freezed.dart';
part 'editorial_model.g.dart';

@freezed
abstract class EditorialModel with _$EditorialModel {
  factory EditorialModel({
    required String title,
    required String subtitle,
    required String imageUrl,
    required String type,
    required String path,
  }) = _EditorialModel;

  factory EditorialModel.fromJson(Map<String, Object?> json) =>
      _$EditorialModelFromJson(json);
}
