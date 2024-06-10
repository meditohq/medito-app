import 'package:freezed_annotation/freezed_annotation.dart';

part 'all_stats_model.freezed.dart';
part 'all_stats_model.g.dart';

@freezed
abstract class AllStatsModel with _$AllStatsModel {
  const factory AllStatsModel({
    required String icon,
    required String color,
    required String title,
    required String subtitle,
  }) = _AllStatsModel;

  factory AllStatsModel.fromJson(Map<String, Object?> json) =>
      _$AllStatsModelFromJson(json);
}
