import 'dart:developer' as dev;
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/local_all_stats.dart';

class AudioCompletionTracker {
  /// Checks if a track was started before midnight but completed after midnight
  /// Returns true if the track crossed midnight
  static bool checkTrackCrossedMidnight({
    required int endTimestamp,
    required int duration,
  }) {
    var endTime = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
    var startTime =
        DateTime.fromMillisecondsSinceEpoch(endTimestamp - duration);

    var startDay = DateTime(startTime.year, startTime.month, startTime.day);
    var endDay = DateTime(endTime.year, endTime.month, endTime.day);

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

    final newDuration = duration + (stats.totalTimeListened ?? 0);
    final newTotalTracks = 1 + (stats.totalTracksCompleted ?? 0);

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
