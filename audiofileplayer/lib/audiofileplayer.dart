import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show AppLifecycleState;

import 'package:audiofileplayer/audio_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

final Logger _logger = Logger('audiofileplayer');

@visibleForTesting
const String channelName = 'audiofileplayer';
const String loadMethod = 'load';
const String flutterPathKey = 'flutterPath';
const String absolutePathKey = 'absolutePath';
const String audioBytesKey = 'audioBytes';
const String remoteUrlKey = 'remoteUrl';
const String audioIdKey = 'audioId';
const String loopingKey = 'looping';
const String playInBackgroundKey = 'playInBackground';
const String releaseMethod = 'release';
const String playMethod = 'play';
const String playFromStartKey = 'playFromStart';
const String endpointSecondsKey = 'endpointSeconds';
const String seekMethod = 'seek';
const String setVolumeMethod = 'setVolume';
const String volumeKey = 'volume';
const String pauseMethod = 'pause';
const String onCompleteCallback = 'onComplete';
const String onDurationCallback = 'onDuration';
const String durationSecondsKey = 'duration_seconds';
const String onPositionCallback = 'onPosition';
const String positionSecondsKey = 'position_seconds';
const String errorCode = 'AudioPluginError';

// Constants for [MediaActionType] and [AndroidMediaButtonType].
const String onMediaEventCallback = 'onMediaEvent';
const String mediaEventTypeKey = 'mediaEventType';
const String mediaStop = 'stop';
const String mediaPause = 'pause';
const String mediaPlay = 'play';
const String mediaPlayPause = 'playPause';
const String mediaNext = 'next';
const String mediaPrevious = 'previous';
const String mediaSeekForward = 'seekForward';
const String mediaSeekBackward = 'seekBackward';
const String mediaSeekTo = 'seekTo';
const String mediaSeekToPositionSecondsKey = 'seekToPositionSeconds';
const String mediaSkipForward = 'skipForward';
const String mediaSkipBackward = 'skipBackward';
const String mediaSkipIntervalSecondsKey = 'skipIntervalSeconds';
const String mediaCustom = 'custom';
const String mediaCustomTitleKey = 'customTitle';
const String mediaCustomEventIdKey = 'customEventId';
const String mediaCustomDrawableResourceKey = 'customDrawableResource';

MethodChannel audioMethodChannel = const MethodChannel(channelName)
  ..setMethodCallHandler(Audio.handleMethodCall);

/// Specifies an action that the OS's background audio system may support.
///
/// Values are used both to request what actions are enabled (see
/// [AudioSystem.setSupportedMediaActionsMethod]), and to specify what types of
/// events have been received (see [MediaEvent]).
///
/// These inform both device displays (i.e. iOS lockscreen/control center) and
/// external controllers (such as watches, auto displays, etc) on what controls
/// to show.
///
/// Note that not all actions are supported on both Android and iOS.
///
/// Not yet supported:
/// - cross-platform functionality: ratings/like/dislike, repeat mode,
///   shuffle mode.
/// - Android-specific functionality: playFromMediaId, playFromSearch,
///   skipToQueueItem, playFromUri.
/// - iOS-specific functionality: bookmark, language.
enum MediaActionType {
  playPause,
  pause,
  play,
  stop,
  next,
  previous,
  seekForward,
  seekBackward,

  /// Enables use seeking in the progress bar.
  seekTo,

  skipForward, // iOS only.
  skipBackward, // iOS only.

  /// Only used when receiving a MediaEvent from an Android custom button.
  custom
}

/// Represents events received from the OS's background audio system (e.g. iOS
/// lockscreen/control center, bluetooth controllers, etc) and from Android
/// buttons in the notification.
class MediaEvent {
  const MediaEvent(this.type,
      {this.customEventId,
      this.seekToPositionSeconds,
      this.skipIntervalSeconds});

  final MediaActionType type;

  /// Set for [MediaActionType.custom].
  final String customEventId;

  /// Set for [MediaActionType.seekTo].
  final double seekToPositionSeconds;

  /// Set for [MediaActionType.skipForward] and [MediaActionType.skipBackward].
  final double skipIntervalSeconds;
}

/// A plugin for audio playback.
///
/// Example usage:
/// ```dart
/// // Play a sound as a one-shot.
/// Audio.load('assets/foo.wav')..play()..dispose();
///
/// // Play a sound, with the ability to play it again, or stop it later.
/// var audio = Audio.load('assets/foo.wav')..play();
/// // ...
/// audio.play();
/// // ...
/// audio.pause();
/// // ...
/// audio.resume();
/// // ...
/// audio.pause();
/// audio.dispose();
///
/// // Do something when playback finishes.
/// var audio = Audio.load('assets/foo.wav', onComplete = () { ... });
/// audio.play();
/// // Note that after calling [dispose], audio playback will continue, and
/// // onComplete will still be run.
/// audio.dispose();
/// ```
///
/// A note on sync and async usage.
/// The async methods below ([play], [pause], etc) may be used sync'ly or
/// async'ly. If used with 'await', they return when the native layer has
/// finished executing the desired operation. This may be useful for
/// synchronizing aural and visual elements. For example:
/// ```dart
/// final audio = Audio.load('foo.wav');
/// audio.play();
/// animationController.forward()
/// ```
/// would send messages to the native layer to begin loading and playback, but
/// return (and start the animation) immediately. Wheras:
/// ```dart
/// final audio = Audio.load('foo.wav');
/// await audio.play();
/// animationController.forward()
/// ```
/// would wait until the native command to play returned, and the audio actually
/// began playing. The animation is therefore more closely synchronized with
/// the start of audio playback.
///
/// A note on Audio lifecycle.
/// Audio objects, and the underlying native audio resources, have different
/// lifespans, depending on usage.
/// Instances of Audio may be kept alive after calls to [dispose] (and, if they
/// are ivars, after their containing parents are dealloc'ed), so that they may
/// continue to receive and handle callbacks (e.g. onComplete).
/// The underlying native audio classes may be kept alive after [dispose] and
/// the deallocation of the parent Audio object, so that audio may continue to
/// play.
/// This command would let the Audio instance deallocate immediately; the
/// underlying resources are released once the file finishes playing.
/// ```dart
/// Audio.load('x.wav')..play()..dispose();
/// ```
/// This command would keep the Audio instance alive for the duration of the
/// playback (so that its onComplete can be called); the underlying resources
/// are released once the file finishes playing.
/// ```dart
/// Audio.load('x.wav', looping:true, onComplete:()=>{...})..play()..dispose();
/// ```
/// ```dart
/// This command would let the Audio instance deallocate immediately; underlying
/// native resources keep playback going forever.
/// ```dart
/// Audio.load('x.wav', looping:true)..play()..dispose();
/// ```
/// While this command would keep the Audio instance alive forever (waiting to
/// run [onComplete]), and also keep native resources playing forever:
/// ```dart
/// Audio.load('x.wav', looping:true, onComplete:()=>{...})..play()..dispose();
/// ```
///
/// Usage with State objects.
/// If your Audio object is an ivar in a State object and it uses a callback
/// (e.g. onComplete) which refers the surrounding class (e.g. a call to
/// setState() or using a sibling ivar), then the callback keeps a strong
/// reference to the surrounding class. Since Audio instances can outlast their
/// parent State objects, that means that the parent State object may be kept
/// alive unnecessarily, unless that strong reference is broken.
/// In State.dispose(), do either:
/// A) If you want the audio to stop playback on parent State disposal, call
///   pause():
///```dart
///  void dispose() {
///    _audio.pause();
///    _audio.dispose();
///    super.dispose();
///  }
///```
/// or
/// B) If you want audio to continue playing back after parent State disposal,
/// call [removeCallbacks]:
///```dart
///  void dispose() {
///    _audio.removeCallbacks();
///    _audio.dispose();
///    super.dispose();
///  }
///```
/// In both cases, [pause] or [removeCallbacks] will signal that the Audio
/// instance need not stay alive (after [dispose]) to call its callbacks.
/// The Audio instance and the parent State will be dealloced.
///
/// Background audio.
/// See README.md for additional per-platform setup for background audio.
/// Use the 'playInBackground' flag on Audio load.
/// ```dart
/// Audio.load('foo.wav', playInBackground = true);
/// ```
/// and use all the methods in [AudioSystem] to communicate desired state and
/// supported behavior to the OS's background audio system.
class Audio with WidgetsBindingObserver {
  Audio._path(this._path, this._onComplete, this._onDuration, this._onPosition,
      this._onError, this._looping, this._playInBackground)
      : _audioId = _uuid.v4(),
        _absolutePath = null,
        _audioBytes = null,
        _remoteUrl = null {
    WidgetsBinding.instance.addObserver(this);
  }

  Audio._absolutePath(this._absolutePath, this._onComplete, this._onDuration,
      this._onPosition, this._onError, this._looping, this._playInBackground)
      : _audioId = _uuid.v4(),
        _path = null,
        _audioBytes = null,
        _remoteUrl = null {
    WidgetsBinding.instance.addObserver(this);
  }

  Audio._byteData(ByteData byteData, this._onComplete, this._onDuration,
      this._onPosition, this._onError, this._looping, this._playInBackground)
      : _audioId = _uuid.v4(),
        _audioBytes = Uint8List.view(byteData.buffer),
        _path = null,
        _absolutePath = null,
        _remoteUrl = null {
    WidgetsBinding.instance.addObserver(this);
  }

  Audio._remoteUrl(this._remoteUrl, this._onComplete, this._onDuration,
      this._onPosition, this._onError, this._looping, this._playInBackground)
      : _audioId = _uuid.v4(),
        _audioBytes = null,
        _path = null,
        _absolutePath = null {
    WidgetsBinding.instance.addObserver(this);
  }

  static final Uuid _uuid = Uuid();

  // All extant, undisposed Audio objects.
  static final Map<String, Audio> _undisposedAudios = <String, Audio>{};
  @visibleForTesting
  static int get undisposedAudiosCount => _undisposedAudios.length;

  // All Audio objects (including disposed ones), that are playing.
  static final Map<String, Audio> _playingAudios = <String, Audio>{};
  @visibleForTesting
  static int get playingAudiosCount => _playingAudios.length;

  // All Audio objects (including disposed ones), that are playing and have an
  // onComplete callback.
  static final Map<String, Audio> _awaitingOnCompleteAudios = <String, Audio>{};
  @visibleForTesting
  static int get awaitingOnCompleteAudiosCount =>
      _awaitingOnCompleteAudios.length;

  // All Audio objects (including disposed ones), that are awaiting an
  // onDuration callback.
  static final Map<String, Audio> _awaitingOnDurationAudios = <String, Audio>{};
  @visibleForTesting
  static int get awaitingOnDurationAudiosCount =>
      _awaitingOnDurationAudios.length;

  // All Audio objects (including disposed ones), that are using an onPosition
  // callback. Audios are added on play()/resume() and removed on
  // pause()/playback completion.
  static final Map<String, Audio> _usingOnPositionAudios = <String, Audio>{};
  @visibleForTesting
  static int get usingOnPositionAudiosCount => _usingOnPositionAudios.length;

  // All Audio objects (including disposed ones), that are using an onError
  // callback.
  static final Map<String, Audio> _usingOnErrorAudios = <String, Audio>{};

  final String _path;
  final String _absolutePath;
  final Uint8List _audioBytes;
  final String _remoteUrl;
  final String _audioId;

  void Function() _onComplete;
  void Function(double duration) _onDuration;
  void Function(double position) _onPosition;
  void Function(String message) _onError;

  bool _looping;
  bool _playing = false;
  double _volume = 1.0;

  /// Whether the [Audio] should continue playback when the app is backgrounded.
  bool _playInBackground = false;

  bool _appPaused = false;

  /// Set while there is playback to a specified point.
  double _endpointSeconds;

  /// Creates an Audio from an asset.
  ///
  /// [path] should be a relative path to Flutter assets, e.g.
  /// `final audio = Audio.load('assets/foo.wav');`
  ///
  /// Returns null if asset cannot be loaded.
  /// Note that it returns an Audio sync'ly, though loading occurs async'ly.
  static Audio load(String path,
      {void onComplete(),
      void onDuration(double duration),
      void onPosition(double position),
      void onError(String message),
      bool looping = false,
      bool playInBackground = false}) {
    final Audio audio = Audio._path(path, onComplete, onDuration, onPosition,
        onError, looping, playInBackground)
      .._load();
    return audio;
  }

  /// Creates an Audio from an absolute path to a file.
  ///
  /// Returns null if asset cannot be loaded.
  /// Note that it returns an Audio sync'ly, though loading occurs async'ly.
  static Audio loadFromAbsolutePath(String path,
      {void onComplete(),
      void onDuration(double duration),
      void onPosition(double position),
      void onError(String message),
      bool looping = false,
      bool playInBackground = false}) {
    final Audio audio = Audio._absolutePath(path, onComplete, onDuration,
        onPosition, onError, looping, playInBackground)
      .._load();
    return audio;
  }

  /// Creates an Audio from a ByteData.
  ///
  /// Returns null if asset cannot be loaded.
  /// Note that it returns an Audio sync'ly, though loading occurs async'ly.
  static Audio loadFromByteData(ByteData byteData,
      {void onComplete(),
      void onDuration(double duration),
      void onPosition(double position),
      void onError(String message),
      bool looping = false,
      bool playInBackground = false}) {
    final Audio audio = Audio._byteData(byteData, onComplete, onDuration,
        onPosition, onError, looping, playInBackground)
      .._load();
    return audio;
  }

  /// Creates an Audio from a remote URL.
  ///
  /// Returns null if url is invalid.
  /// Note that it returns an Audio sync'ly, though loading occurs async'ly.
  /// Note that onError will fire if remote loading fails (due to connectivity,
  /// invalid url, etc); this usually is fairly quick on iOS, but waits for
  /// a longer timeout on Android.
  static Audio loadFromRemoteUrl(String url,
      {void onComplete(),
      void onDuration(double duration),
      void onPosition(double position),
      void onError(String message),
      bool looping = false,
      bool playInBackground = false}) {
    if (Uri.tryParse(url) == null) return null;
    final Audio audio = Audio._remoteUrl(url, onComplete, onDuration,
        onPosition, onError, looping, playInBackground)
      .._load();
    return audio;
  }

  /// Loads an asset.
  ///
  /// Keeps strong reference to this Audio (for channel callback routing)
  /// and requests underlying resource loading.
  Future<void> _load() async {
    assert(_path != null ||
        _absolutePath != null ||
        _audioBytes != null ||
        _remoteUrl != null);
    assert(!_undisposedAudios.containsKey(_audioId));
    _logger.info('Loading audio $_audioId');
    // Note that we add the _audioId to _undisposedAudios before invoking a
    // load, anticipating success, so that _load() may be called async'ly, with
    // a subsequent call to play().
    _undisposedAudios[_audioId] = this;
    if (_onDuration != null) _awaitingOnDurationAudios[_audioId] = this;
    if (_onError != null) _usingOnErrorAudios[_audioId] = this;

    try {
      await _sendMethodCall(_audioId, loadMethod, <String, dynamic>{
        flutterPathKey: _path,
        absolutePathKey: _absolutePath,
        audioBytesKey: _audioBytes,
        remoteUrlKey: _remoteUrl,
        audioIdKey: _audioId,
        loopingKey: _looping,
        playInBackgroundKey: _playInBackground
      });
    } on PlatformException catch (e) {
      // Note that exceptions during [_load] are assumed to have failed to
      // create underlying resources, so a call to [_releaseNative] is not
      // required. Just remove the instance from the static structures it was
      // added to within this call to [_load].
      _undisposedAudios.remove(_audioId);
      _awaitingOnDurationAudios.remove(_audioId);
      final Audio audio = _usingOnErrorAudios.remove(_audioId);
      if (audio != null) {
        // Audio has an onError callback.
        audio._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  /// Dispose this Audio.
  ///
  /// This must be called before object falls out of its local scope, or else
  /// a memory leak may occur. Once [dispose] is called, no further calls to
  /// the Audio object are accepted.
  /// Triggers release of the underlying audio resources, either immediately,
  /// or on playback completion.
  /// Note that on calling [dispose], audio playback will continue, and
  /// onComplete will still be called on playback completion.
  Future<void> dispose() async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called dispose() on a disposed Audio');
      return;
    }
    _undisposedAudios.remove(_audioId);

    // If not playing, call for release immediately. Otherwise (if audio is
    // playing) it will be called when playback completes.
    if (!_playing) {
      _usingOnErrorAudios.remove(_audioId);
      WidgetsBinding.instance.removeObserver(this);
      await _releaseNative(_audioId);
    }
  }

  /// Remove callbacks from this Audio.
  ///
  /// This is useful when audio playback outlasts the lifespan of its parent
  /// object. If the Audio object has callbacks which retain the surrounding
  /// parent object, it will keep that parent object alive until it is finished
  /// playback (even after a call to [dispose]). This may not be desired,
  /// particularly if the callbacks are used just to update the parent object
  /// (i.e. they call setState() on a State object). Calling removeCallbacks on
  /// the parent object (e.g. in a State.dispose()) will break that reference.
  void removeCallbacks() {
    _onComplete = null;
    _awaitingOnCompleteAudios.remove(_audioId);
    _onDuration = null;
    _awaitingOnDurationAudios.remove(_audioId);
    _onPosition = null;
    _usingOnPositionAudios.remove(_audioId);
  }

  /// Plays this [Audio] content from the beginning.
  ///
  /// Note that remote audio streams should not call this to begin playback;
  /// call [resume] instead. Android systems will throw an error if attempting
  /// to seek to the start of a remote audio stream.
  ///
  /// If [endpointSeconds] is specified, playback will resume until that point,
  /// then stop playback and trigger an onComplete callback. If not specified,
  /// audio will play to the end of the file.
  Future<void> play([double endpointSeconds]) async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called play() on a disposed Audio');
      return;
    }
    await _playHelper(playFromStart: true, endpointSeconds: endpointSeconds);
  }

  /// Resumes audio playback from the current playback position.
  ///
  /// Note that on a freshly-loaded Audio (at playback position zero), this is
  /// equivalent to calling [play].
  ///
  /// If [endpointSeconds] is specified, playback will resume until that point,
  /// then stop playback and trigger an onComplete callback. If not specified,
  /// audio will play to the end of the file.
  Future<void> resume([double endpointSeconds]) async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called resume() on a disposed Audio');
      return;
    }
    await _playHelper(playFromStart: false, endpointSeconds: endpointSeconds);
  }

  // Shared code for both [play] and [resume].
  Future<void> _playHelper(
      {@required bool playFromStart, @required double endpointSeconds}) async {
    _playing = true;
    _playingAudios[_audioId] = this;
    _endpointSeconds = endpointSeconds;

    if (_onComplete != null) {
      // If there is an onComplete, put [this] into a data structure to keep
      // it alive until playback completes and onComplete can be run.
      _awaitingOnCompleteAudios[_audioId] = this;
    }
    if (_onPosition != null) {
      _usingOnPositionAudios[_audioId] = this;
    }

    // If app is paused and audio should not play, return early. On app resume,
    // the _playing flag will signify that audio should resume.
    if (_appPaused && !_playInBackground) return;

    await _playNative(playFromStart, endpointSeconds);
  }

  /// Pauses playing audio.
  Future<void> pause() async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called pause() on a disposed Audio');
      return;
    }

    _playing = false;
    _playingAudios.remove(_audioId);
    _usingOnPositionAudios.remove(_audioId);

    // If audio is in [_awaitingOnCompleteAudios], remove it, without calling
    // its _onComplete();
    _awaitingOnCompleteAudios.remove(_audioId);

    await _pauseNative();
  }

  /// Seeks to a playback position.
  ///
  /// May be used while either playing or paused. Returns when the seek is
  /// complete.
  Future<void> seek(double positionSeconds) async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called seek() on a disposed Audio');
      return;
    }

    try {
      await _sendMethodCall(_audioId, seekMethod, <String, dynamic>{
        audioIdKey: _audioId,
        positionSecondsKey: positionSeconds
      });
    } on PlatformException catch (e) {
      if (_usingOnErrorAudios.containsKey(_audioId)) {
        // Audio has an onError callback.
        _usingOnErrorAudios[_audioId]._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  /// Gets/Sets volume.
  /// Note that this is a linear amplitude multiplier; callers should use a sqrt
  /// value of 0-1 to get an equal-power fade, e.g. 'half volume' should
  /// be audio.setVolume(sqrt(.5)), to get something that 'sounds' half as
  /// loud as 'full' volume.
  double get volume => _volume;

  Future<void> setVolume(double volume) async {
    if (!_undisposedAudios.containsKey(_audioId)) {
      _logger.severe('Called set volume on a disposed Audio');
      return;
    }
    if (volume < 0.0 || volume > 1.0) {
      _logger.warning(
          'Invalid volume value $volume is begin clamped to 0.0 to 1.0.');
      volume.clamp(0.0, 1.0);
    }

    _volume = volume;

    try {
      await _sendMethodCall(_audioId, setVolumeMethod,
          <String, dynamic>{audioIdKey: _audioId, volumeKey: volume});
    } on PlatformException catch (e) {
      if (_usingOnErrorAudios.containsKey(_audioId)) {
        // Audio has an onError callback.
        _usingOnErrorAudios[_audioId]._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  /// Handle audio lifecycle changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _appPaused = true;
      if (_playing && !_playInBackground) {
        _pauseNative();
      }
    } else if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      if (_playing && !_playInBackground) {
        _playNative(false, _endpointSeconds);
      }
    }
  }

  /// Sends method call for starting playback.
  Future<void> _playNative(bool playFromStart, double endpointSeconds) async {
    try {
      final Map<String, dynamic> args = <String, dynamic>{
        audioIdKey: _audioId,
        playFromStartKey: playFromStart
      };
      if (endpointSeconds != null) args[endpointSecondsKey] = endpointSeconds;
      await _sendMethodCall(_audioId, playMethod, args);
    } on PlatformException catch (e) {
      if (_usingOnErrorAudios.containsKey(_audioId)) {
        // Audio has an onError callback.
        _usingOnErrorAudios[_audioId]._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  /// Sends method call for pausing playback.
  Future<void> _pauseNative() async {
    try {
      await _sendMethodCall(
          _audioId, pauseMethod, <String, dynamic>{audioIdKey: _audioId});
    } on PlatformException catch (e) {
      if (_usingOnErrorAudios.containsKey(_audioId)) {
        // Audio has an onError callback.
        _usingOnErrorAudios[_audioId]._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  /// Handles callback from native layer, signifying that an [Audio] has
  /// completed playback.
  ///
  /// Removes the audio instance from various data structures. If the audio
  /// has previously been disposed, releases native resources.
  static void _onCompleteNative(String audioId) {
    // Remove from playingAudios, and set instance's [_playing] to false.
    final Audio playingAudio = _playingAudios[audioId];
    _playingAudios.remove(audioId);
    playingAudio._playing = false;

    // Check if audio has previously been disposed.
    final Audio undisposedAudio = _undisposedAudios[audioId];
    if (undisposedAudio == null) {
      // The audio has been disposed, so release native resources.
      _usingOnErrorAudios.remove(audioId);
      WidgetsBinding.instance.removeObserver(undisposedAudio);
      _releaseNative(audioId);
    }

    // If audio is in [_awaitingOnCompleteAudios], remove it and call its
    // _onComplete();
    _awaitingOnCompleteAudios.remove(audioId)?._onComplete();
    // If audio is in [_usingOnPositionAudios], remove it.
    _usingOnPositionAudios.remove(audioId);
  }

  /// Handles callback from native layer, signifying that a newly loaded Audio
  /// has computed its duration.
  static void _onDurationNative(String audioId, double durationSeconds) {
    // If audio is in [_awaitingOnDurationAudios], remove it and call its
    // _onDuration.
    _awaitingOnDurationAudios.remove(audioId)?._onDuration(durationSeconds);
  }

  /// Handles callback from native layer, signifying playback position updates.
  static void _onPositionNative(String audioId, double positionSeconds) {
    _usingOnPositionAudios[audioId]?._onPosition(positionSeconds);
  }

  /// Release underlying audio assets.
  static Future<void> _releaseNative(String audioId) async {
    try {
      await _sendMethodCall(
          audioId, releaseMethod, <String, dynamic>{audioIdKey: audioId});
    } on PlatformException catch (e) {
      if (_usingOnErrorAudios.containsKey(audioId)) {
        // Audio has an onError callback.
        _usingOnErrorAudios[audioId]._onError(e.message);
      } else {
        // Audio does not use an onError callback: rethrow the exception.
        rethrow;
      }
    }
  }

  // Subsequent methods interact directly with native layers.

  /// Call channel.invokeMethod, wrapped in a block to highlight/report errors.
  static Future<void> _sendMethodCall(String audioId, String method,
      [dynamic arguments]) async {
    try {
      await audioMethodChannel.invokeMethod<dynamic>(method, arguments);
    } on PlatformException catch (e) {
      _logger.severe(
          '_sendMethodCall error: audioId: $audioId method: $method', e);
      // Calling methods should do any cleanup. Then, either call the _onError
      // callback (if the audio uses it), or rethrow again.
      rethrow;
    }
  }

  /// Handle method callbacks from the native layer.
  @visibleForTesting
  static Future<void> handleMethodCall(MethodCall call) async {
    final Map<dynamic, dynamic> arguments = call.arguments;
    final String audioId = arguments[audioIdKey];
    switch (call.method) {
      case onCompleteCallback:
        _onCompleteNative(audioId);
        break;
      case onDurationCallback:
        final double durationSeconds = arguments[durationSecondsKey];
        _onDurationNative(audioId, durationSeconds);
        break;
      case onPositionCallback:
        final double positionSeconds = arguments[positionSecondsKey];
        _onPositionNative(audioId, positionSeconds);
        break;
      case onMediaEventCallback:
        AudioSystem.instance.handleNativeMediaEventCallback(arguments);
        break;
      default:
        _logger.severe('Unknown method ${call.method}');
    }
  }
}
