import 'dart:async';

import 'package:medito/models/track/track_model.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../../src/audio_pigeon.g.dart';

class IosAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  IosAudioHandler() {
    _init();
  }

  Duration get position => _player.position;

  bool get playing => _player.playerState.playing;

  bool get isComplete =>
      _player.playerState.processingState == ProcessingState.completed;

  final _trackStateSubject = BehaviorSubject<Track>();

  Track get trackState => _trackStateSubject.value;

  Stream<Track> get _trackStateStream => _trackStateSubject.stream;

  Stream<Duration> get positionStream => _player.positionStream;

  Duration? get duration => _player.duration;

  Stream<IosStateData> get iosStateStream => Rx.combineLatest6<double,
          PlayerState, Track, Duration, Duration, Duration?, IosStateData>(
        _player.speedStream,
        _player.playerStateStream,
        _trackStateStream,
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (speed, state, track, position, bufferedPosition, duration) {
          return IosStateData(
            speed,
            state,
            track,
            position,
            bufferedPosition,
            duration ?? Duration.zero,
          );
        },
      );

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    iosStateStream.listen(
      (event) {
        mediaItem.add(
          MediaItem(
            id: event.track.toString(),
            title: event.track.title,
            artist: event.track.artist,
            duration: event.duration,
            artUri: Uri.parse(event.track.imageUrl),
          ),
        );
      },
    );

    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.pause,
          MediaAction.play,
          MediaAction.stop,
        },
        playing: playing,
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _player.setSpeed(speed);
  }

  @override
  Future<void> play() async {
    unawaited(_player.play());
    unawaited(iosBackgroundPlayer.play());
  }

  @override
  Future<void> pause() async {
    unawaited(_player.pause());
    unawaited(iosBackgroundPlayer.pause());
  }

  @override
  Future<void> stop() async {
    unawaited(_player.stop());
    unawaited(iosBackgroundPlayer.pause());
    unawaited(super.stop());
  }

  Future<void> setUrl(
      String? downloadPath, TrackFilesModel file, Track trackData) async {
    if (downloadPath == null) {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(
            file.path,
          ),
        ),
      );
    } else {
      await _player.setAsset(
        downloadPath,
      );
    }
    _trackStateSubject.add(trackData);
  }
}

class IosStateData {
  final double speed;
  final PlayerState playerState;
  final Track track;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  IosStateData(
    this.speed,
    this.playerState,
    this.track,
    this.position,
    this.bufferedPosition,
    this.duration,
  );
}
