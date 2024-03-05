import 'package:freezed_annotation/freezed_annotation.dart';

part 'shortcuts_model.freezed.dart';
part 'shortcuts_model.g.dart';

@unfreezed
abstract class ShortcutsModel with _$ShortcutsModel {
  factory ShortcutsModel({
    required String id,
    required String type,
    required String title,
    required String path,
  }) = _ShortcutsModel;

  factory ShortcutsModel.fromJson(Map<String, Object?> json) =>
      _$ShortcutsModelFromJson(json);
}
