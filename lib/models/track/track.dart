import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

@freezed
abstract class Track with _$Track {
  const factory Track({
    required String id,
    required String title,
    String? subtitle,
    required String description,
    required String coverUrl,
    required bool isPublished,
    @Default(false) bool isLiked,
    required bool hasBackgroundSound,
    @Default(null) TrackArtist? artist,
    @Default(<TrackVoice>[]) @JsonKey(name: 'audio') List<TrackVoice> voices,
  }) = _Track;

  factory Track.fromJson(Map<String, Object?> json) => _$TrackFromJson(json);
}

@freezed
abstract class TrackArtist with _$TrackArtist {
  const factory TrackArtist({required String name, required String path}) =
      _TrackArtist;

  factory TrackArtist.fromJson(Map<String, Object?> json) =>
      _$TrackArtistFromJson(json);
}

@freezed
abstract class TrackVoice with _$TrackVoice {
  const factory TrackVoice({
    String? guideName,
    @Default(<TrackAudioFile>[])
    @JsonKey(name: 'files')
    List<TrackAudioFile> audioFiles,
  }) = _TrackVoice;

  factory TrackVoice.fromJson(Map<String, Object?> json) =>
      _$TrackVoiceFromJson(json);
}

@freezed
abstract class TrackAudioFile with _$TrackAudioFile {
  const factory TrackAudioFile({
    required String id,
    required String path,
    required int duration,
  }) = _TrackAudioFile;

  factory TrackAudioFile.fromJson(Map<String, Object?> json) =>
      _$TrackAudioFileFromJson(json);
}
