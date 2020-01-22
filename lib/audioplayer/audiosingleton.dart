import 'package:audioplayers/audioplayers.dart';

class MeditoAudioPlayer {
  static final MeditoAudioPlayer _singleton = MeditoAudioPlayer._internal();
  AudioPlayer audioPlayer = AudioPlayer();

  factory MeditoAudioPlayer() {
    return _singleton;
  }

  MeditoAudioPlayer._internal();
}
