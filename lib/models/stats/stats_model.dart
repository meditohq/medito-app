import 'package:Medito/models/stats/all_stats/all_stats_model.dart';
import 'package:Medito/models/stats/mini_stats/mini_stats_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_model.freezed.dart';
part 'stats_model.g.dart';

@freezed
abstract class StatsModel with _$StatsModel {
  const factory StatsModel({
    @Default([]) List<MiniStatsModel> mini,
    @Default([]) List<AllStatsModel> all,
  }) = _StatsModel;

  factory StatsModel.fromJson(Map<String, Object?> json) =>
      _$StatsModelFromJson(json);
}
