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
    return files.reduce(
      (a, b) =>
          (a.duration - targetMs).abs() < (b.duration - targetMs).abs() ? a : b,
    );
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

  /// The defaults to remember when the user plays [voice] / [file] from the
  /// track screen. Playing what was preselected counts as a choice, so this
  /// fills in whichever default is still unset — but only when the track
  /// offered a choice, so a single-voice or single-length track never decides
  /// it. Saved defaults are left alone; the pickers change those.
  static ({String? guideName, int? durationMs}) defaultsFromPlay(
    Track track,
    TrackVoice voice,
    TrackAudioFile file, {
    String? savedGuideName,
    int? savedDurationMs,
  }) {
    final guide = voice.guideName;
    final pickedVoice =
        savedGuideName == null &&
        track.voices.length > 1 &&
        guide != null &&
        guide.isNotEmpty;
    final pickedDuration =
        savedDurationMs == null && voice.audioFiles.length > 1;
    return (
      guideName: pickedVoice ? guide : null,
      durationMs: pickedDuration ? file.duration : null,
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
