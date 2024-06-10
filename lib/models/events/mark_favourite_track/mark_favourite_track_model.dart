import 'package:freezed_annotation/freezed_annotation.dart';

part 'mark_favourite_track_model.freezed.dart';
part 'mark_favourite_track_model.g.dart';

@freezed
abstract class MarkFavouriteTrackModel with _$MarkFavouriteTrackModel {
  const factory MarkFavouriteTrackModel({
    required String audioFileId,
    required String trackId,
  }) = _MarkFavouriteTrackModel;

  factory MarkFavouriteTrackModel.fromJson(Map<String, Object?> json) =>
      _$MarkFavouriteTrackModelFromJson(json);
}
