import 'package:freezed_annotation/freezed_annotation.dart';

part 'shortcuts_model.freezed.dart';
part 'shortcuts_model.g.dart';

@freezed
class ShortcutsModel with _$ShortcutsModel {
  const factory ShortcutsModel({
    required String id,
    required String type,
    required String title,
    required String path,
  }) = _ShortcutsModel;

  factory ShortcutsModel.fromJson(Map<String, dynamic> json) =>
      _$ShortcutsModelFromJson(json);
}