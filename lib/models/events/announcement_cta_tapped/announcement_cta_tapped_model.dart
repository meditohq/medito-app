import 'package:freezed_annotation/freezed_annotation.dart';
part 'announcement_cta_tapped_model.freezed.dart';
part 'announcement_cta_tapped_model.g.dart';

@freezed
abstract class AnnouncementCtaTappedModel with _$AnnouncementCtaTappedModel {
  const factory AnnouncementCtaTappedModel({
    required String name,
    required AnnouncementCtaTappedPayloadModel payload,
  }) = _AnnouncementCtaTappedModel;

  factory AnnouncementCtaTappedModel.fromJson(Map<String, Object?> json) =>
      _$AnnouncementCtaTappedModelFromJson(json);
}

@freezed
abstract class AnnouncementCtaTappedPayloadModel
    with _$AnnouncementCtaTappedPayloadModel {
  const factory AnnouncementCtaTappedPayloadModel({
    required int announcementId,
    required String ctaTitle,
  }) = _AnnouncementCtaTappedPayloadModel;

  factory AnnouncementCtaTappedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$AnnouncementCtaTappedPayloadModelFromJson(json);
}
