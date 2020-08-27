import 'package:Medito/audioplayer/audio_player_task.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerSingleton {

  static final AudioPlayerSingleton _singleton =
      AudioPlayerSingleton._internal();

  AudioPlayerTask audioPlayerTask = new AudioPlayerTask();

  AudioPlayer player = new AudioPlayer();

  factory AudioPlayerSingleton() {
    return _singleton;
  }

  AudioPlayerSingleton._internal();
}
