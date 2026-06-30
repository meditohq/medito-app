import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stats/all_stats_model.dart';

part 'local_all_stats.g.dart';

// NOTE ON SCHEMA EVOLUTION AND BACKUPS:
// When this class changes in the future (adding, removing, or modifying fields),
// it will affect the stored backups in StatsBackupService.
//
// Schema versioning is implemented in the StatsBackupService (not in this model)
// by storing a 'version' field alongside the serialized stats.
//
// If/when the schema changes:
// 1. Increment the version number in StatsBackupService
// 2. Add a mapper/migration function in StatsBackupService to handle old versions
// 3. Ensure backward compatibility by properly mapping old data to new structure
//
// This approach keeps this model clean while handling versioning at the backup level.

@JsonSerializable()
class LocalAllStats {
  static const int defaultMaxStreakFreezes = 2;

  final int streakCurrent;
  final int streakLongest;
  final int totalTracksCompleted;
  final int totalTimeListened;
  final List<String>? tracksChecked;
  final List<LocalAudioCompleted>? audioCompleted;
  final int updated;
  final int? streakFreezes;
  final int? maxStreakFreezes;
  @JsonKey(defaultValue: [])
  final List<int> freezeUsageDates;
  final double consistencyScore;

  LocalAllStats({
    required this.streakCurrent,
    required this.streakLongest,
    required this.totalTracksCompleted,
    required this.totalTimeListened,
    required this.tracksChecked,
    required this.audioCompleted,
    required this.updated,
    this.streakFreezes = 0,
    this.maxStreakFreezes = 0,
    required this.freezeUsageDates,
    this.consistencyScore = 0,
  });

  factory LocalAllStats.empty() {
    return LocalAllStats(
      streakCurrent: 0,
      streakLongest: 0,
      totalTracksCompleted: 0,
      totalTimeListened: 0,
      tracksChecked: [],
      audioCompleted: [],
      updated: 0,
      streakFreezes: 1,
      maxStreakFreezes: defaultMaxStreakFreezes,
      freezeUsageDates: [],
      consistencyScore: 0,
    );
  }

  factory LocalAllStats.fromAllStats(AllStats stats) {
    return LocalAllStats(
      streakCurrent: 0,
      streakLongest: stats.streakLongest,
      totalTracksCompleted: stats.totalTracksCompleted,
      totalTimeListened: stats.totalTimeListened,
      tracksChecked: stats.tracksChecked ?? [],
      audioCompleted:
          stats.audioCompleted
              ?.map((e) => LocalAudioCompleted.fromAudioCompleted(e))
              .toList() ??
          [],
      updated: stats.updated,
      streakFreezes: stats.streakFreezes > 0 ? stats.streakFreezes : 1,
      maxStreakFreezes: stats.maxStreakFreezes > 0
          ? stats.maxStreakFreezes
          : defaultMaxStreakFreezes,
      freezeUsageDates: stats.freezeUsageDates,
      consistencyScore: 0,
    );
  }

  AllStats toAllStats() {
    return AllStats(
      streakLongest: streakLongest,
      totalTracksCompleted: totalTracksCompleted,
      totalTimeListened: totalTimeListened,
      tracksChecked: tracksChecked,
      audioCompleted: audioCompleted?.map((e) => e.toAudioCompleted()).toList(),
      updated: updated,
      streakFreezes: streakFreezes ?? 0,
      maxStreakFreezes: maxStreakFreezes ?? 0,
      freezeUsageDates: freezeUsageDates,
    );
  }

  factory LocalAllStats.fromJson(Map<String, dynamic> json) =>
      _$LocalAllStatsFromJson(json);

  Map<String, dynamic> toJson() => _$LocalAllStatsToJson(this);

  LocalAllStats copyWith({
    int? streakCurrent,
    int? streakLongest,
    int? totalTracksCompleted,
    int? totalTimeListened,
    List<String>? tracksChecked,
    List<LocalAudioCompleted>? audioCompleted,
    int? updated,
    int? streakFreezes,
    int? maxStreakFreezes,
    List<int>? freezeUsageDates,
    double? consistencyScore,
  }) {
    return LocalAllStats(
      streakCurrent: streakCurrent ?? this.streakCurrent,
      streakLongest: streakLongest ?? this.streakLongest,
      totalTracksCompleted: totalTracksCompleted ?? this.totalTracksCompleted,
      totalTimeListened: totalTimeListened ?? this.totalTimeListened,
      tracksChecked: tracksChecked ?? this.tracksChecked,
      audioCompleted: audioCompleted ?? this.audioCompleted,
      updated: updated ?? this.updated,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      maxStreakFreezes: maxStreakFreezes ?? this.maxStreakFreezes,
      freezeUsageDates: freezeUsageDates ?? this.freezeUsageDates,
      consistencyScore: consistencyScore ?? this.consistencyScore,
    );
  }
}
