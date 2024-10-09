import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/stats/all_stats_model.dart';

part 'local_audio_completed.g.dart';

@JsonSerializable()
class LocalAudioCompleted {
  final int timestamp;
  final String id;

  LocalAudioCompleted({required this.timestamp, required this.id});

  factory LocalAudioCompleted.fromJson(Map<String, dynamic> json) => _$LocalAudioCompletedFromJson(json);
  Map<String, dynamic> toJson() => _$LocalAudioCompletedToJson(this);

  // Convert from API model to local model
  factory LocalAudioCompleted.fromAudioCompleted(AudioCompleted audioCompleted) {
    return LocalAudioCompleted(
      timestamp: audioCompleted.timestamp,
      id: audioCompleted.id,
    );
  }

  // Convert to API model
  AudioCompleted toAudioCompleted() {
    return AudioCompleted(
      timestamp: timestamp,
      id: id,
    );
  }
}