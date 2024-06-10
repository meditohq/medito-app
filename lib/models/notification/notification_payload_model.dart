import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_payload_model.freezed.dart';
part 'notification_payload_model.g.dart';

@freezed
abstract class NotificationPayloadModel with _$NotificationPayloadModel {
  const factory NotificationPayloadModel({
    required String id,
    required String? type,
    String? path,
    required String action,
  }) = _NotificationPayloadModel;

  factory NotificationPayloadModel.fromJson(Map<String, Object?> json) =>
      _$NotificationPayloadModelFromJson(json);
}
