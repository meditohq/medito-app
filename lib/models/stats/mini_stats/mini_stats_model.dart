import 'package:freezed_annotation/freezed_annotation.dart';

part 'mini_stats_model.freezed.dart';
part 'mini_stats_model.g.dart';

@freezed
abstract class MiniStatsModel with _$MiniStatsModel {
  const factory MiniStatsModel({
    required String icon,
    required int value,
  }) = _MiniStatsModel;

  factory MiniStatsModel.fromJson(Map<String, Object?> json) =>
      _$MiniStatsModelFromJson(json);
}
