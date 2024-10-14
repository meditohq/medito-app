import 'package:flutter/foundation.dart';

class AllStats {
  final int streakCurrent;
  final int streakLongest;
  final int totalTracksCompleted;
  final int totalTimeListened;
  final List<String>? tracksCompleted;
  final List<AudioCompleted>? audioCompleted;
  final int updated;

  AllStats({
    required this.streakCurrent,
    required this.streakLongest,
    required this.totalTracksCompleted,
    required this.totalTimeListened,
    required this.tracksCompleted,
    required this.audioCompleted,
    required this.updated,
  });

  factory AllStats.fromJson(Map<String, dynamic> json) {
    return AllStats(
      streakCurrent: json['streak_current'] as int? ?? 0,
      streakLongest: json['streak_longest'] as int? ?? 0,
      totalTracksCompleted: json['total_tracks_completed'] as int? ?? 0,
      totalTimeListened: json['total_time_listened'] as int? ?? 0,
      tracksCompleted: (json['tracks_completed'] as List<dynamic>?)?.cast<String>() ?? [],
      audioCompleted: (json['audio_completed'] as List<dynamic>?)
          ?.map((item) => AudioCompleted.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      updated: json['updated'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streak_current': streakCurrent,
      'streak_longest': streakLongest,
      'total_tracks_completed': totalTracksCompleted,
      'total_time_listened': totalTimeListened,
      'tracks_completed': tracksCompleted,
      'audio_completed': audioCompleted?.map((item) => item.toJson()).toList(),
      'updated': updated,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllStats &&
          runtimeType == other.runtimeType &&
          streakCurrent == other.streakCurrent &&
          streakLongest == other.streakLongest &&
          totalTracksCompleted == other.totalTracksCompleted &&
          totalTimeListened == other.totalTimeListened &&
          listEquals(tracksCompleted, other.tracksCompleted) &&
          listEquals(audioCompleted, other.audioCompleted) &&
          updated == other.updated;

  @override
  int get hashCode =>
      streakCurrent.hashCode ^
      streakLongest.hashCode ^
      totalTracksCompleted.hashCode ^
      totalTimeListened.hashCode ^
      tracksCompleted.hashCode ^
      audioCompleted.hashCode ^
      updated.hashCode;
}

class AudioCompleted {
  final int timestamp;
  final String id;

  AudioCompleted({
    required this.timestamp,
    required this.id,
  });

  factory AudioCompleted.fromJson(Map<String, dynamic> json) {
    return AudioCompleted(
      timestamp: json['timestamp'] as int,
      id: json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'id': id,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioCompleted &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          id == other.id;

  @override
  int get hashCode => timestamp.hashCode ^ id.hashCode;
}
