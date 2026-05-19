import 'package:medito/models/track/track.dart';

/// Picks the voice and audio-file variant of a [Track] that best matches the
/// user's saved preferences. Centralises the matching rules so every entry
/// point (TrackView, Up Next, path tile, etc.) resolves the same way.
class TrackVariantSelector {
  TrackVariantSelector._();

  /// Returns the file whose duration is closest to [targetMs]. Falls back to
  /// the first file when no target is supplied or only one option exists.
  static TrackAudioFile closestDuration(
    List<TrackAudioFile> files,
    int? targetMs,
  ) {
    if (files.length == 1 || targetMs == null) return files.first;
    return files.reduce((a, b) =>
        (a.duration - targetMs).abs() < (b.duration - targetMs).abs() ? a : b);
  }

  /// Returns the voice matching [guideName], or the first voice when there is
  /// no preference or no match.
  static TrackVoice voiceByGuideName(
    List<TrackVoice> voices,
    String? guideName,
  ) {
    if (guideName == null) return voices.first;
    return voices.firstWhere(
      (v) => v.guideName == guideName,
      orElse: () => voices.first,
    );
  }

  /// Resolves both the voice and the audio file in one shot.
  static ({TrackVoice voice, TrackAudioFile file}) resolve(
    Track track, {
    String? guideName,
    int? durationMs,
  }) {
    final voice = voiceByGuideName(track.voices, guideName);
    final file = closestDuration(voice.audioFiles, durationMs);
    return (voice: voice, file: file);
  }
}
