import 'package:pigeon/pigeon.dart';

// to build the classes: flutter pub run pigeon --input pigeon_conf.dart

// #docregion config
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/audio_pigeon.g.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      'android/app/src/main/kotlin/com/meditofoundation/medito/AudioPigeon.g.kt',
  kotlinOptions: KotlinOptions(),
  // swiftOut: 'ios/Runner/Messages.g.swift',
  // swiftOptions: SwiftOptions(),
))
// #enddocregion config

// #docregion host-definitions
//ignore:prefer-match-file-name
class AudioData {
  AudioData({
    required this.url,
    required this.track,
  });

  String url;
  Track track;
}

@HostApi()
abstract class MeditoAndroidAudioServiceManager {
  void startService();
}

@HostApi()
abstract class MeditoAudioServiceApi {
  bool playAudio(AudioData audioData);

  void playPauseAudio();

  void stopAudio();

  void setSpeed(double speed);

  void seekToPosition(int position);

  void skip10SecondsForward();

  void skip10SecondsBackward();

  void setBackgroundSound(String? uri);

  void setBackgroundSoundVolume(double volume);

  void stopBackgroundSound();

  void playBackgroundSound();

}

// #enddocregion host-definitions

// #docregion flutter-definitions
class PlaybackState {
  bool isPlaying;
  bool isBuffering;
  bool isSeeking;
  bool isCompleted;
  int position;
  int duration;
  Speed speed;
  int volume;
  Track track;
  BackgroundSound? backgroundSound;

  PlaybackState({
    required this.isPlaying,
    required this.isBuffering,
    required this.isSeeking,
    required this.isCompleted,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
    required this.track,
    this.backgroundSound,
  });
}

class BackgroundSound {
  String? uri;
  String title;

  BackgroundSound({
    required this.uri,
    required this.title,
  });
}

class Speed {
  double speed;

  Speed({required this.speed});
}

class Track {
  String title;
  String description;
  String imageUrl;
  String? artist;
  String? artistUrl;

  Track({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.artist,
    this.artistUrl,
  });

}

@FlutterApi()
abstract class MeditoAudioServiceCallbackApi {
  void updatePlaybackState(PlaybackState state);
}
// #enddocregion flutter-definitions
