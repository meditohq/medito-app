import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement_cta_tapped_model.freezed.dart';
part 'announcement_cta_tapped_model.g.dart';

@freezed
abstract class AnnouncementCtaTappedModel with _$AnnouncementCtaTappedModel {
  const factory AnnouncementCtaTappedModel({
    required String announcementId,
    required String ctaTitle,
  }) = _AnnouncementCtaTappedModel;

  factory AnnouncementCtaTappedModel.fromJson(Map<String, Object?> json) =>
      _$AnnouncementCtaTappedModelFromJson(json);
}
