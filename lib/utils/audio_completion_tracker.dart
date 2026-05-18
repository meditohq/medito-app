import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/day_boundary.dart';

class AudioCompletionTracker {
  /// Checks if a track crossed the user-perceived day boundary.
  ///
  /// With `dayBoundaryOffset = Duration.zero` (default) this is the legacy
  /// midnight check. A positive offset (e.g. +4h) shifts the boundary later,
  /// so a late-night session no longer counts as "crossing".
  static bool checkTrackCrossedMidnight({
    required int endTimestamp,
    required int duration,
    Duration dayBoundaryOffset = Duration.zero,
  }) {
    var endTime = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
    var startTime =
        DateTime.fromMillisecondsSinceEpoch(endTimestamp - duration);

    final startDay = dayOf(startTime, dayBoundaryOffset);
    final endDay = dayOf(endTime, dayBoundaryOffset);

    return startDay.isBefore(endDay);
  }

  /// Updates stats with a new completed audio track
  static LocalAllStats updateStatsWithCompletedAudio({
    required LocalAllStats? stats,
    required LocalAudioCompleted audioCompleted,
    required int duration,
  }) {
    if (stats == null) {
      return LocalAllStats.empty().copyWith(
        audioCompleted: [audioCompleted],
        tracksChecked: [audioCompleted.id],
        totalTracksCompleted: 1,
        totalTimeListened: duration,
        updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }

    final newDuration = duration + (stats.totalTimeListened);
    final newTotalTracks = 1 + (stats.totalTracksCompleted);

    var updatedTracksCompleted = stats.tracksChecked ?? [];
    if (!updatedTracksCompleted.contains(audioCompleted.id)) {
      updatedTracksCompleted.add(audioCompleted.id);
    }

    return stats.copyWith(
      tracksChecked: updatedTracksCompleted,
      audioCompleted: [...?stats.audioCompleted, audioCompleted],
      totalTracksCompleted: newTotalTracks,
      updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      totalTimeListened: newDuration,
    );
  }
}
