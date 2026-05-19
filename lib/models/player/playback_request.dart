import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/track/track.dart';

part 'playback_request.freezed.dart';
part 'playback_request.g.dart';

/// Everything the player needs to start (and keep showing) a track: a single
/// resolved voice + length variant, plus enough metadata to render the player
/// UI, lock screen, and notification without reaching back into the full
/// [Track] graph.
@freezed
abstract class PlaybackRequest with _$PlaybackRequest {
  const factory PlaybackRequest({
    required String trackId,
    required String fileId,
    required String title,
    required String description,
    required String coverUrl,
    required String remoteUrl,
    required int duration,
    required bool hasBackgroundSound,
    String? guideName,
    TrackArtist? artist,
  }) = _PlaybackRequest;

  factory PlaybackRequest.fromJson(Map<String, Object?> json) =>
      _$PlaybackRequestFromJson(json);

  factory PlaybackRequest.fromTrack(
    Track track,
    TrackVoice voice,
    TrackAudioFile file,
  ) =>
      PlaybackRequest(
        trackId: track.id,
        fileId: file.id,
        title: track.title,
        description: track.description,
        coverUrl: track.coverUrl,
        remoteUrl: file.path,
        duration: file.duration,
        hasBackgroundSound: track.hasBackgroundSound,
        guideName: voice.guideName,
        artist: track.artist,
      );
}
