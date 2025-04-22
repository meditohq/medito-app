import 'package:medito/models/local_audio_completed.dart';

class Stats {
  final int streakCurrent;
  final List<LocalAudioCompleted> audioCompleted;
  final int updated;

  Stats({
    required this.streakCurrent,
    required this.audioCompleted,
    required this.updated,
  });
}
