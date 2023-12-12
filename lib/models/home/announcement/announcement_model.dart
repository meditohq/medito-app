import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement_model.freezed.dart';
part 'announcement_model.g.dart';

@freezed
abstract class AnnouncementModel with _$AnnouncementModel {
  const factory AnnouncementModel({
    required String id,
    required String text,
    required String colorBackground,
    required String colorText,
    String? icon,
    String? ctaTitle,
    String? ctaType,
    String? ctaPath,
  }) = _AnnouncementModel;

  factory AnnouncementModel.fromJson(Map<String, Object?> json) =>
      _$AnnouncementModelFromJson(json);
}
