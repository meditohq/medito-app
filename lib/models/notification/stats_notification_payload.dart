import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_notification_payload.freezed.dart';
part 'stats_notification_payload.g.dart';

@freezed
class StatsNotificationPayload with _$StatsNotificationPayload {

  const factory StatsNotificationPayload({
    required String trackId,
    required int duration,
    required String fileId,
    required String guide,
    required int timestamp,
    required String userToken,
  }) = _StatsNotificationPayload;

  factory StatsNotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$StatsNotificationPayloadFromJson(json);
}
