import 'package:freezed_annotation/freezed_annotation.dart';
part 'transfer_stats_model.freezed.dart';
part 'transfer_stats_model.g.dart';

@freezed
abstract class TransferStatsModel with _$TransferStatsModel {
  const factory TransferStatsModel({
    required String name,
    required TransferStatsModel payload,
  }) = _TransferStatsModel;

  factory TransferStatsModel.fromJson(Map<String, Object?> json) =>
      _$TransferStatsModelFromJson(json);
}

@freezed
abstract class TransferStatsPayloadModel with _$TransferStatsPayloadModel {
  const factory TransferStatsPayloadModel({
    required int currentStreak,
    required int minutesListened,
    required int listendedSessionsNum,
    required int longestStreak,
    required List<int> listenedSessionIds,
  }) = _TransferStatsPayloadModel;

  factory TransferStatsPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$TransferStatsPayloadModelFromJson(json);
}
