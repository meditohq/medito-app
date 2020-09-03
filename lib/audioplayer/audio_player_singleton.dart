import 'package:Medito/audioplayer/audio_player_task.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerSingleton {

  static final AudioPlayerSingleton _singleton =
      AudioPlayerSingleton._internal();

  MeditoAudioPlayerTask audioPlayerTask = new MeditoAudioPlayerTask();

  Duration duration = Duration();

  AudioPlayer player = new AudioPlayer();

  factory AudioPlayerSingleton() {
    return _singleton;
  }

  AudioPlayerSingleton._internal();
}
