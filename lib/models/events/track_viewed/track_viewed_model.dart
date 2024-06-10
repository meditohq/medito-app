import 'package:freezed_annotation/freezed_annotation.dart';

part 'track_viewed_model.freezed.dart';
part 'track_viewed_model.g.dart';

@freezed
abstract class TrackViewedModel with _$TrackViewedModel {
  const factory TrackViewedModel({
    required String trackId,
  }) = _TrackViewedModel;

  factory TrackViewedModel.fromJson(Map<String, Object?> json) =>
      _$TrackViewedModelFromJson(json);
}
