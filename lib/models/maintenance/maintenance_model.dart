import 'package:freezed_annotation/freezed_annotation.dart';

part 'maintenance_model.freezed.dart';
part 'maintenance_model.g.dart';

@freezed
abstract class MaintenanceModel with _$MaintenanceModel {
  const factory MaintenanceModel({
    @Default(0) int? minimumBuildNumber,
    String? message,
    String? ctaLabel,
    String? ctaUrl,
    @Default(false) bool isUnderMaintenance,
  }) = _MaintenanceModel;

  factory MaintenanceModel.fromJson(Map<String, Object?> json) =>
      _$MaintenanceModelFromJson(json);
}
