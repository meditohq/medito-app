import 'dart:async';
import 'package:medito/models/models.dart' show PlaybackRequest;
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/constants/http/http_constants.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/stats_updater.dart';
import '../../utils/logger.dart';

class IosAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _httpApiService = HttpApiService();
  bool _isInitialized = false;
  RepeatMode _currentRepeatMode = RepeatMode.none;
  bool _hasReplayedOnce = false;

  IosAudioHandler();

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    try {
      final session = await AudioSession.instance;

      // Configure interruption handling
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_player.volume * 0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_player.volume * 2.0);
              break;
            case AudioInterruptionType.pause:
              if (_player.playing) {
                _player.play();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        _player.pause();
      });

      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      ));

      _setupPlaybackState();
      _setupEventListeners();

      _isInitialized = true;
    } catch (e) {
      AppLogger.e('IOS', 'Failed to initialize audio session: $e');
      rethrow;
    }
  }

  void _setupPlaybackState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setSpeed,
        MediaAction.pause,
        MediaAction.play,
      },
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));
  }

  void _setupEventListeners() {
    iosStateStream.listen(
      (event) {
        mediaItem.add(
          MediaItem(
            id: event.track.toString(),
            title: event.track.title,
            artist: event.track.artist,
            duration: event.duration,
            artUri: Uri.parse(event.track.imageUrl),
            playable: true,
            displayTitle: event.track.title,
            displaySubtitle: event.track.artist,
          ),
        );

        playbackState.add(playbackState.value.copyWith(
          updatePosition: event.position,
          bufferedPosition: event.bufferedPosition,
          speed: event.speed,
          playing: event.playerState.playing,
        ));
      },
    );

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        // Handle repeat once mode
        if (_currentRepeatMode == RepeatMode.once && !_hasReplayedOnce) {
          _hasReplayedOnce = true;
          await _player.seek(Duration.zero);
          await _player.play();
          return;
        }

        await _storeTrackCompletion();
      }
    });

    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
          MediaAction.pause,
          MediaAction.play,
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
      AppLogger.e(
          'IOS', 'Error processing track completion in AudioHandler: $e');
    }
  }

  /// Creates a payload map with all track completion data
  Future<Map<String, dynamic>> _createTrackCompletionPayload() async {
    String? userToken = await _getUserToken();

    return {
      TypeConstants.trackIdKey: trackState.id,
      TypeConstants.durationIdKey: duration?.inMilliseconds ?? 0,
      TypeConstants.fileIdKey: trackState.fileId,
      TypeConstants.guideIdKey: trackState.artist ?? '',
      TypeConstants.timestampIdKey: DateTime.now().millisecondsSinceEpoch,
      UpdateStatsConstants.userTokenKey: userToken,
    };
  }

  /// Try to update stats directly and return success status
  Future<bool> _tryUpdateStats(Map<String, dynamic> payload) async {
    try {
      AppLogger.d('IOS', 'Track completed: ${trackState.id}');
      final success = await handleStats(payload);

      if (success) {
        AppLogger.d('IOS', 'Successfully updated stats from audio handler');
        return true;
      }
    } catch (e) {
      AppLogger.e(
          'IOS', 'Error updating stats directly from audio handler: $e');
    }
    return false;
  }

  /// Store track completion data for later processing
  Future<void> _storeForLaterProcessing(Map<String, dynamic> payload) async {
    AppLogger.d(
        'IOS', 'Storing track completion for later processing: ${trackState.id}');
    final prefs = await SharedPreferences.getInstance();
    await storeTrackCompletion(prefs, payload);
  }

  Future<String?> _getUserToken() async {
    try {
      final response = await _httpApiService.getRequest(HTTPConstants.me);
      return response['userToken'] as String?;
    } catch (e) {
      AppLogger.e('IOS', 'Error getting user token: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(SharedPreferenceConstants.userToken);
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

  Future<void> setCustomRepeatMode(RepeatMode mode) async {
    _currentRepeatMode = mode;
    _hasReplayedOnce = false;

    switch (mode) {
      case RepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.once:
        await _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.infinite:
        await _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);

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
      String? downloadPath, PlaybackRequest request, Track trackData) async {
    await ensureInitialized();

    _hasReplayedOnce = false;

    if (downloadPath == null) {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(
            request.remoteUrl,
          ),
        ),
      );
    } else {
      await _player.setAsset(
        downloadPath,
      );
    }

    await setCustomRepeatMode(_currentRepeatMode);

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
