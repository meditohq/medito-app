import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_menu_model.freezed.dart';
part 'home_menu_model.g.dart';

@freezed
abstract class HomeMenuModel with _$HomeMenuModel {
  const factory HomeMenuModel({
    required String id,
    required String icon,
    required String type,
    required String title,
    required String path,
  }) = _HomeMenuModel;

  factory HomeMenuModel.fromJson(Map<String, Object?> json) =>
      _$HomeMenuModelFromJson(json);
}
