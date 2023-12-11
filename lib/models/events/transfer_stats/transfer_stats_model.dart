import 'package:freezed_annotation/freezed_annotation.dart';

part 'transfer_stats_model.freezed.dart';
part 'transfer_stats_model.g.dart';

@freezed
abstract class TransferStatsModel with _$TransferStatsModel {
  const factory TransferStatsModel({
    required int currentStreak,
    required int minutesListened,
    required int listenedSessionsNum,
    required int longestStreak,
    required List<int> listenedSessionIds,
  }) = _TransferStatsModel;

  factory TransferStatsModel.fromJson(Map<String, Object?> json) =>
      _$TransferStatsModelFromJson(json);
}
