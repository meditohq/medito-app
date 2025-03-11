import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:medito/models/track/track_model.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/stats_updater.dart';

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
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    ));

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

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await _storeTrackCompletion();
      }
    });

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

  Future<void> _storeTrackCompletion() async {
    try {
      if (duration == null) return;

      final payload = await _createTrackCompletionPayload();

      // Try to update stats immediately
      if (await _tryUpdateStats(payload)) {
        return;
      }

      // Failed to update stats directly, store for later processing
      await _storeForLaterProcessing(payload);
    } catch (e) {
      debugPrint('Error processing track completion in AudioHandler: $e');
    }
  }

  /// Creates a payload map with all track completion data
  Future<Map<String, dynamic>> _createTrackCompletionPayload() async {
    String? userToken = await _getUserToken();

    return {
      TypeConstants.trackIdKey: trackState.id,
      TypeConstants.durationIdKey: duration?.inMilliseconds ?? 0,
      TypeConstants.fileIdKey: mediaItem.value?.title ?? '',
      TypeConstants.guideIdKey: trackState.artist ?? '',
      TypeConstants.timestampIdKey: DateTime.now().millisecondsSinceEpoch,
      UpdateStatsConstants.userTokenKey: userToken,
    };
  }

  /// Try to update stats directly and return success status
  Future<bool> _tryUpdateStats(Map<String, dynamic> payload) async {
    try {
      debugPrint('Track completed: ${trackState.id}');
      final success = await handleStats(payload);

      if (success) {
        debugPrint('Successfully updated stats from audio handler');
        return true;
      }
    } catch (e) {
      debugPrint('Error updating stats directly from audio handler: $e');
    }
    return false;
  }

  /// Store track completion data for later processing
  Future<void> _storeForLaterProcessing(Map<String, dynamic> payload) async {
    debugPrint(
        'Storing track completion for later processing: ${trackState.id}');
    final prefs = await SharedPreferences.getInstance();
    await storeTrackCompletion(prefs, payload);
  }

  Future<String?> _getUserToken() async {
    try {
      var user = Supabase.instance.client.auth.currentUser;
      if (user?.userMetadata != null) {
        return user?.userMetadata?['userToken'] as String?;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(SharedPreferenceConstants.userToken);
    } catch (e) {
      debugPrint('Error getting user token: $e');
      return null;
    }
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
