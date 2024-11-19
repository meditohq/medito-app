import 'package:freezed_annotation/freezed_annotation.dart';

part 'track_model.freezed.dart';
part 'track_model.g.dart';

@unfreezed
abstract class TrackModel with _$TrackModel {
  const TrackModel._();

  factory TrackModel({
    required String id,
    required String title,
    String? subtitle,
    required String description,
    required String coverUrl,
    required bool isPublished,
    @Default(false) bool isLiked,
    required bool hasBackgroundSound,
    @Default(null) TrackArtistModel? artist,
    @Default(<TrackAudioModel>[]) List<TrackAudioModel> audio,
  }) = _TrackModel;

  factory TrackModel.fromJson(Map<String, Object?> json) =>
      _$TrackModelFromJson(json);

  TrackModel customCopyWith() {
    return TrackModel(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      coverUrl: coverUrl,
      isPublished: isPublished,
      isLiked: isLiked,
      hasBackgroundSound: hasBackgroundSound,
      artist: artist,
      audio: [
        ...audio
            .map(
              (e) => TrackAudioModel(
                guideName: e.guideName,
                files: [
                  ...e.files.map((e) => e),
                ],
              ),
            ),
      ],
    );
  }
}

@unfreezed
abstract class TrackArtistModel with _$TrackArtistModel {
  factory TrackArtistModel({required String name, required String path}) =
      _TrackArtistModel;

  factory TrackArtistModel.fromJson(Map<String, Object?> json) =>
      _$TrackArtistModelFromJson(json);
}

@unfreezed
abstract class TrackAudioModel with _$TrackAudioModel {
  factory TrackAudioModel({
    String? guideName,
    @Default([]) List<TrackFilesModel> files,
  }) = _TrackAudioModel;

  factory TrackAudioModel.fromJson(Map<String, Object?> json) =>
      _$TrackAudioModelFromJson(json);
}

@unfreezed
abstract class TrackFilesModel with _$TrackFilesModel {
  factory TrackFilesModel({
    required String id,
    required String path,
    required int duration,
  }) = _TrackFilesModel;

  factory TrackFilesModel.fromJson(Map<String, Object?> json) =>
      _$TrackFilesModelFromJson(json);
}
