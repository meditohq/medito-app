import 'dart:io' show Directory, Platform;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audiofileplayer/audiofileplayer.dart';
import 'package:audiofileplayer/audio_system.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

final Logger _logger = Logger('audiofileplayer_example');

void main() => runApp(MyApp());

/// This app shows several use cases for the audiofileplayer plugin.
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Identifiers for the two custom Android notification buttons.
  static const String replayButtonId = 'replayButtonId';
  static const String newReleasesButtonId = 'newReleasesButtonId';

  /// Preloaded audio data for the first card.
  Audio _audio;
  bool _audioPlaying = false;
  double _audioDurationSeconds;
  double _audioPositionSeconds;
  double _audioVolume = 1.0;
  double _seekSliderValue = 0.0; // Normalized 0.0 - 1.0.

  /// On-the-fly audio data for the second card.
  int _spawnedAudioCount = 0;
  ByteData _audioByteData;

  /// Remote url audio data for the third card.
  Audio _remoteAudio;
  bool _remoteAudioPlaying = false;
  bool _remoteAudioLoading = false;
  String _remoteErrorMessage;

  /// Background audio data for the fourth card.
  Audio _backgroundAudio;
  bool _backgroundAudioPlaying;
  double _backgroundAudioDurationSeconds;
  double _backgroundAudioPositionSeconds = 0;

  /// Local file data for the fifth card.
  String _documentsPath;
  Audio _documentAudio;
  bool _documentAudioPlaying = false;
  String _documentErrorMessage;

  /// The iOS audio category dropdown item in the last (iOS-only) card.
  IosAudioCategory _iosAudioCategory = IosAudioCategory.playback;

  @override
  void initState() {
    super.initState();
    AudioSystem.instance.addMediaEventListener(_mediaEventListener);
    // First card.
    _audio = Audio.load('assets/audio/printermanual.m4a',
        onComplete: () => setState(() => _audioPlaying = false),
        onDuration: (double durationSeconds) =>
            setState(() => _audioDurationSeconds = durationSeconds),
        onPosition: (double positionSeconds) => setState(() {
              _audioPositionSeconds = positionSeconds;
              _seekSliderValue = _audioPositionSeconds / _audioDurationSeconds;
            }));
    // Second card.
    _loadAudioByteData();
    // Third card
    _loadRemoteAudio();
    // Fourth card.
    _backgroundAudio = Audio.load('assets/audio/printermanual.m4a',
        onDuration: (double durationSeconds) =>
            _backgroundAudioDurationSeconds = durationSeconds,
        onPosition: (double positionSeconds) =>
            _backgroundAudioPositionSeconds = positionSeconds,
        looping: true,
        playInBackground: true);
    _backgroundAudioPlaying = false;
    // Fifth card.
    _loadDocumentPathAudio();
  }

  @override
  void dispose() {
    AudioSystem.instance.removeMediaEventListener(_mediaEventListener);
    _audio.dispose();
    if (_remoteAudio != null) {
      _remoteAudio.dispose();
    }
    _backgroundAudio.dispose();
    super.dispose();
  }

  static Widget _transportButtonWithTitle(
          String title, bool isPlaying, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: RaisedButton(
                    onPressed: onTap,
                    child: isPlaying
                        ? Image.asset("assets/icons/ic_pause_black_48dp.png")
                        : Image.asset(
                            "assets/icons/ic_play_arrow_black_48dp.png")),
              ),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(title)),
            ],
          ));

  /// Convert double seconds to String minutes:seconds.
  static String _stringForSeconds(double seconds) {
    if (seconds == null) return null;
    return '${(seconds ~/ 60)}:${(seconds.truncate() % 60).toString().padLeft(2, '0')}';
  }

  /// Listener for transport control events from the OS.
  ///
  /// Note that this example app does not handle all event types.
  void _mediaEventListener(MediaEvent mediaEvent) {
    _logger.info('App received media event of type: ${mediaEvent.type}');
    final MediaActionType type = mediaEvent.type;
    if (type == MediaActionType.play) {
      _resumeBackgroundAudio();
    } else if (type == MediaActionType.pause) {
      _pauseBackgroundAudio();
    } else if (type == MediaActionType.playPause) {
      _backgroundAudioPlaying
          ? _pauseBackgroundAudio()
          : _resumeBackgroundAudio();
    } else if (type == MediaActionType.stop) {
      _stopBackgroundAudio();
    } else if (type == MediaActionType.seekTo) {
      _backgroundAudio.seek(mediaEvent.seekToPositionSeconds);
      AudioSystem.instance
          .setPlaybackState(true, mediaEvent.seekToPositionSeconds);
    } else if (type == MediaActionType.skipForward) {
      final double skipIntervalSeconds = mediaEvent.skipIntervalSeconds;
      _logger.info(
          'Skip-forward event had skipIntervalSeconds $skipIntervalSeconds.');
      _logger.info('Skip-forward is not implemented in this example app.');
    } else if (type == MediaActionType.skipBackward) {
      final double skipIntervalSeconds = mediaEvent.skipIntervalSeconds;
      _logger.info(
          'Skip-backward event had skipIntervalSeconds $skipIntervalSeconds.');
      _logger.info('Skip-backward is not implemented in this example app.');
    } else if (type == MediaActionType.custom) {
      if (mediaEvent.customEventId == replayButtonId) {
        _backgroundAudio.play();
        AudioSystem.instance.setPlaybackState(true, 0.0);
      } else if (mediaEvent.customEventId == newReleasesButtonId) {
        _logger
            .info('New-releases button is not implemented in this exampe app.');
      }
    }
  }

  void _loadAudioByteData() async {
    _audioByteData = await rootBundle.load('assets/audio/sinesweep.mp3');
    setState(() {});
  }

  void _loadRemoteAudio() {
    _remoteErrorMessage = null;
    _remoteAudioLoading = true;
    _remoteAudio = Audio.loadFromRemoteUrl('https://streams.kqed.org/kqedradio',
        onDuration: (_) => setState(() => _remoteAudioLoading = false),
        onError: (String message) => setState(() {
              _remoteErrorMessage = message;
              _remoteAudio.dispose();
              _remoteAudio = null;
              _remoteAudioPlaying = false;
              _remoteAudioLoading = false;
            }));
  }

  /// Load audio from local file 'foo.mp3'.
  ///
  /// For Android, use external directory. For iOS, use documents directory.
  void _loadDocumentPathAudio() async {
    final Directory directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    setState(() => _documentsPath = directory.path);

    _documentAudio = Audio.loadFromAbsolutePath(
        '$_documentsPath${Platform.pathSeparator}foo.mp3',
        onComplete: () => setState(() => _documentAudioPlaying = false),
        onError: (String message) => setState(() {
              _documentErrorMessage = message;
              _documentAudio.dispose();
            }));
  }

  Future<void> _resumeBackgroundAudio() async {
    _backgroundAudio.resume();
    setState(() => _backgroundAudioPlaying = true);

    final Uint8List imageBytes = await generateImageBytes();
    AudioSystem.instance.setMetadata(AudioMetadata(
        title: "Great title",
        artist: "Great artist",
        album: "Great album",
        genre: "Great genre",
        durationSeconds: _backgroundAudioDurationSeconds,
        artBytes: imageBytes));

    AudioSystem.instance
        .setPlaybackState(true, _backgroundAudioPositionSeconds);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.pause,
      AndroidMediaButtonType.stop,
      const AndroidCustomMediaButton(
          'replay', replayButtonId, 'ic_replay_black_36dp')
    ], androidCompactIndices: <int>[
      0
    ]);

    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.pause,
      MediaActionType.next,
      MediaActionType.previous,
      MediaActionType.skipForward,
      MediaActionType.skipBackward,
      MediaActionType.seekTo,
    }, skipIntervalSeconds: 30);
  }

  void _pauseBackgroundAudio() {
    _backgroundAudio.pause();
    setState(() => _backgroundAudioPlaying = false);

    AudioSystem.instance
        .setPlaybackState(false, _backgroundAudioPositionSeconds);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.play,
      AndroidMediaButtonType.stop,
      const AndroidCustomMediaButton(
          'new releases', newReleasesButtonId, 'ic_new_releases_black_36dp'),
    ], androidCompactIndices: <int>[
      0
    ]);

    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.play,
      MediaActionType.next,
      MediaActionType.previous,
    });
  }

  void _stopBackgroundAudio() {
    _backgroundAudio.pause();
    setState(() => _backgroundAudioPlaying = false);
    AudioSystem.instance.stopBackgroundDisplay();
  }

  /// Generates a 200x200 png, with randomized colors, to use as art for the
  /// notification/lockscreen.
  static Future<Uint8List> generateImageBytes() async {
    // Random color generation methods: pick contrasting hues.
    final Random random = Random();
    final double bgHue = random.nextDouble() * 360;
    final double fgHue = (bgHue + 180.0) % 360;
    final HSLColor bgHslColor =
        HSLColor.fromAHSL(1.0, bgHue, random.nextDouble() * .5 + .5, .5);
    final HSLColor fgHslColor =
        HSLColor.fromAHSL(1.0, fgHue, random.nextDouble() * .5 + .5, .5);

    final Size size = const Size(200.0, 200.0);
    final Offset center = const Offset(100.0, 100.0);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Rect rect = Offset.zero & size;
    final Canvas canvas = Canvas(recorder, rect);
    final Paint bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = bgHslColor.toColor();
    final Paint fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = fgHslColor.toColor()
      ..strokeWidth = 8;
    // Draw background color.
    canvas.drawRect(rect, bgPaint);
    // Draw 5 inset squares around the center.
    for (int i = 0; i < 5; i++) {
      canvas.drawRect(
          Rect.fromCenter(center: center, width: i * 40.0, height: i * 40.0),
          fgPaint);
    }
    // Render to image, then compress to PNG ByteData, then return as Uint8List.
    final ui.Image image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final ByteData encodedImageData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return encodedImageData.buffer.asUint8List();
  }

  // Creates a card, out of column child widgets. Injects vertical padding
  // around the column children.
  Widget _cardWrapper(List<Widget> columnChildren) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: columnChildren
                  .map((Widget child) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: child,
                      ))
                  .toList())));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      backgroundColor: const Color(0xFFCCCCCC),
      appBar: AppBar(
        title: const Text('Audio file player example'),
      ),
      body: ListView(children: <Widget>[
        // A card controlling a pre-loaded (on app start) audio object.
        _cardWrapper(<Widget>[
          const Text('Example 1: preloaded asset audio.'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            _transportButtonWithTitle('play from start', false, () {
              _audio.play();
              setState(() => _audioPlaying = true);
            }),
            _transportButtonWithTitle(
                _audioPlaying ? 'pause' : 'resume', _audioPlaying, () {
              _audioPlaying ? _audio.pause() : _audio.resume();
              setState(() => _audioPlaying = !_audioPlaying);
            }),
            _transportButtonWithTitle(
                _audioPlaying ? 'pause' : 'play 0:05 to 0:10', _audioPlaying,
                () async {
              if (_audioPlaying) {
                _audio.pause();
              } else {
                await _audio.seek(5);
                _audio.resume(10);
              }
              setState(() => _audioPlaying = !_audioPlaying);
            }),
          ]),
          Row(
            children: <Widget>[
              Text(_stringForSeconds(_audioPositionSeconds) ?? ''),
              Expanded(child: Container()),
              Text(_stringForSeconds(_audioDurationSeconds) ?? ''),
            ],
          ),
          Slider(
              value: _seekSliderValue,
              onChanged: (double val) {
                setState(() => _seekSliderValue = val);
                final double positionSeconds = val * _audioDurationSeconds;
                _audio.seek(positionSeconds);
              }),
          const Text('drag to seek'),
          Slider(
              value: _audioVolume,
              onChanged: (double val) {
                setState(() => _audioVolume = val);
                _audio.setVolume(_audioVolume);
              }),
          const Text('volume (linear amplitude)'),
        ]),
        _cardWrapper(<Widget>[
          const Text(
            'Example 2: one-shot audio playback.\nTap multiple times to spawn overlapping instances.',
            textAlign: TextAlign.center,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            _transportButtonWithTitle('audio from assets', false, () {
              Audio.load('assets/audio/sinesweep.mp3',
                  onComplete: () => setState(() => --_spawnedAudioCount))
                ..play()
                ..dispose();
              setState(() => ++_spawnedAudioCount);
            }),
            _transportButtonWithTitle(
                'audio from ByteData',
                false,
                _audioByteData == null
                    ? null
                    : () {
                        Audio.loadFromByteData(_audioByteData,
                            onComplete: () =>
                                setState(() => --_spawnedAudioCount))
                          ..play()
                          ..dispose();
                        setState(() => ++_spawnedAudioCount);
                      })
          ]),
          Text('Spawned audio count: $_spawnedAudioCount'),
        ]),
        _cardWrapper(<Widget>[
          const Text('Example 3: play remote stream'),
          _transportButtonWithTitle(
              'resume/pause NPR (KQED) live stream',
              _remoteAudioPlaying,
              _remoteAudioLoading
                  ? null
                  : () {
                      if (!_remoteAudioPlaying) {
                        // If remote audio loading previously failed with an
                        // error, attempt to reload.
                        if (_remoteAudio == null) _loadRemoteAudio();
                        // Note call to resume(), not play(). play() attempts to
                        // seek to the start of a file, which, for streams, will
                        // fail with an error on Android platforms, so streams
                        // should use resume() to begin playback.
                        _remoteAudio.resume();
                        setState(() => _remoteAudioPlaying = true);
                      } else {
                        _remoteAudio.pause();
                        setState(() => _remoteAudioPlaying = false);
                      }
                    }),
          _remoteErrorMessage != null
              ? Text(_remoteErrorMessage,
                  style: const TextStyle(color: const Color(0xFFFF0000)))
              : Text(_remoteAudioLoading ? 'loading...' : 'loaded')
        ]),
        _cardWrapper(<Widget>[
          const Text(
            'Example 4: background playback with notification/lockscreen data.',
            textAlign: TextAlign.center,
          ),
          _transportButtonWithTitle(
              _backgroundAudioPlaying ? 'pause' : 'resume',
              _backgroundAudioPlaying,
              () => _backgroundAudioPlaying
                  ? _pauseBackgroundAudio()
                  : _resumeBackgroundAudio()),
        ]),
        _cardWrapper(<Widget>[
          Text(
            'Example 5: load local files from disk.\n\nPut a file named \'foo.mp3\' in the app\'s ${Platform.isAndroid ? 'external files' : 'documents'} folder, then restart the app.',
            textAlign: TextAlign.center,
          ),
          _transportButtonWithTitle(
              _documentAudioPlaying ? 'pause' : 'play', _documentAudioPlaying,
              () {
            _documentAudioPlaying
                ? _documentAudio.pause()
                : _documentAudio.play();
            setState(() => _documentAudioPlaying = !_documentAudioPlaying);
          }),
          if (_documentErrorMessage != null)
            Text(_documentErrorMessage,
                style: const TextStyle(color: const Color(0xFFFF0000)))
        ]),
        if (Platform.isIOS)
          _cardWrapper(<Widget>[
            const Text('(iOS only) iOS audio category:'),
            DropdownButton<IosAudioCategory>(
              value: _iosAudioCategory,
              onChanged: (IosAudioCategory newValue) {
                setState(() {
                  _iosAudioCategory = newValue;
                  AudioSystem.instance.setIosAudioCategory(_iosAudioCategory);
                });
              },
              items: IosAudioCategory.values.map((IosAudioCategory category) {
                return DropdownMenuItem<IosAudioCategory>(
                  value: category,
                  child: Text(category.toString()),
                );
              }).toList(),
            )
          ]),
      ]),
    ));
  }
}
