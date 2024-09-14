import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_model.freezed.dart';

part 'stats_model.g.dart';

@freezed
class StatsModel with _$StatsModel {
  const factory StatsModel({
    @Default([]) List<AllStatsModel> all,
    @Default([]) List<TilesModel> mini,
  }) = _StatsModel;

  factory StatsModel.fromJson(Map<String, dynamic> json) =>
      _$StatsModelFromJson(json);

  factory StatsModel.empty() => const StatsModel();
}

@freezed
class AllStatsModel with _$AllStatsModel {
  const factory AllStatsModel({
    required String icon,
    required String color,
    required String title,
    required String subtitle,
  }) = _AllStatsModel;

  factory AllStatsModel.fromJson(Map<String, dynamic> json) =>
      _$AllStatsModelFromJson(json);
}

@freezed
class TilesModel with _$TilesModel {
  const factory TilesModel({
    required String icon,
    required String color,
    required String title,
    required String subtitle,
  }) = _TilesModel;

  factory TilesModel.fromJson(Map<String, dynamic> json) =>
      _$TilesModelFromJson(json);
}
