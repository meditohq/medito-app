import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stats/all_stats_model.dart';

part 'local_all_stats.g.dart';

@JsonSerializable()
class LocalAllStats {
  final int streakCurrent;
  final int streakLongest;
  final int totalTracksCompleted;
  final int totalTimeListened;
  final List<String>? tracksChecked;
  final List<LocalAudioCompleted>? audioCompleted;
  final int updated;

  LocalAllStats({
    required this.streakCurrent,
    required this.streakLongest,
    required this.totalTracksCompleted,
    required this.totalTimeListened,
    required this.tracksChecked,
    required this.audioCompleted,
    required this.updated,
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
    );
  }

  factory LocalAllStats.fromAllStats(AllStats stats) {
    return LocalAllStats(
      streakCurrent: stats.streakCurrent,
      streakLongest: stats.streakLongest,
      totalTracksCompleted: stats.totalTracksCompleted,
      totalTimeListened: stats.totalTimeListened,
      tracksChecked: stats.tracksChecked ?? [],
      audioCompleted: stats.audioCompleted
              ?.map((e) => LocalAudioCompleted.fromAudioCompleted(e))
              .toList() ??
          [],
      updated: stats.updated,
    );
  }

  AllStats toAllStats() {
    return AllStats(
      streakCurrent: streakCurrent,
      streakLongest: streakLongest,
      totalTracksCompleted: totalTracksCompleted,
      totalTimeListened: totalTimeListened,
      tracksChecked: tracksChecked,
      audioCompleted: audioCompleted?.map((e) => e.toAudioCompleted()).toList(),
      updated: updated,
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
  }) {
    return LocalAllStats(
      streakCurrent: streakCurrent ?? this.streakCurrent,
      streakLongest: streakLongest ?? this.streakLongest,
      totalTracksCompleted: totalTracksCompleted ?? this.totalTracksCompleted,
      totalTimeListened: totalTimeListened ?? this.totalTimeListened,
      tracksChecked: tracksChecked ?? this.tracksChecked,
      audioCompleted: audioCompleted ?? this.audioCompleted,
      updated: updated ?? this.updated,
    );
  }
}
