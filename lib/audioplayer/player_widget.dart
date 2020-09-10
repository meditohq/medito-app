import 'dart:async';
import 'dart:math';

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/audio_complete_copy_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';

class PlayerWidget extends StatefulWidget {
  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String titleText = "Well done for taking time for yourself!";
  String subTitleText =
      "Taking care of yourself is important. We’re here to help you do it, for free, forever.";
  String buttonLabel = "Donate";
  String buttonUrl = "http://meditofoundation.org/donate";
  String buttonIcon = "assets/images/ic_gift.svg";
  String artUrl;
  Color textColor;
  Color coverColorAsColor;

  @override
  void dispose() {
    try {
      AudioService.stop();
    } catch (e) {
      print("stop error!");
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    AudioCompleteCopyProvider provider = AudioCompleteCopyProvider();

    provider.fetchCopy().then((value) {
      if (value != null) {
        titleText = value.title;
        subTitleText = value.subtitle;
        buttonLabel = value.buttonLabel;
        buttonUrl = value.buttonDestination;
        buttonIcon = buttonIcon.replaceFirst("ic_gift", value.buttonIcon);

      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: MeditoColors.midnight,
      body: StreamBuilder<ScreenState>(
        stream: _screenStateStream,
        builder: (context, snapshot) {
          final screenState = snapshot.data;
          final mediaItem = screenState?.mediaItem;
          final state = screenState?.playbackState;
          final processingState =
              state?.processingState ?? AudioProcessingState.none;
          final playing = state?.playing ?? false;

          getTextColor(mediaItem);
          getCoverColor(mediaItem);
          getArtUrl(mediaItem);

          return Stack(
            children: [
              Column(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      color: coverColorAsColor,
                      child: Center(
                        child: FractionallySizedBox(
                            widthFactor: .43,
                            child: artUrl != null
                                ? Image.network(artUrl)
                                : Container()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 28.0, left: 16.0, bottom: 8.0, right: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            mediaItem?.title ?? titleText,
                            style: GoogleFonts.merriweather().copyWith(
                                letterSpacing: 0.4,
                                fontSize: 26.0,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, bottom: 24.0, right: 16.0),
                    child: Row(children: [
                      mediaItem?.extras != null
                          ? Text(
                              mediaItem?.extras['attr'] ?? 'Loading...',
                              style: Theme.of(context)
                                  .textTheme
                                  .headline1
                                  .copyWith(color: MeditoColors.newGrey),
                            )
                          : Expanded(
                              child: Text(
                              subTitleText,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline1
                                  .copyWith(color: MeditoColors.newGrey),
                            )),
                    ]),
                  ),
                  mediaItem == null
                      ? Container()
                      : positionIndicator(mediaItem, state, coverColorAsColor),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 16.0),
                    child: Row(
                      children: [
                        (processingState == AudioProcessingState.buffering ||
                                processingState ==
                                    AudioProcessingState.connecting)
                            ? buildCircularIndicatorRow()
                            : Expanded(
                                child: mediaItem == null
                                    ? getDonateAndShareButton()
                                    : getPlayingOrPausedButton(playing),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _onBackPressed,
                    color: textColor,
                  ),
                ),
              ),
            ],
          );

//            return Column(
//              mainAxisAlignment: MainAxisAlignment.center,
//              children: [
//                if (processingState == AudioProcessingState.buffering) ...[
//                  CircularProgressIndicator(),
//                  Text('buffering'),
//                ] else if (processingState ==
//                    AudioProcessingState.buffering) ...[
//                  CircularProgressIndicator(),
//                  Text('connecting'),
//                ] else if (processingState == AudioProcessingState.none) ...[
//                  Text('none')
//                ] else ...[
//                  if (mediaItem?.title != null) Text(mediaItem.title),
//                  Row(
//                    mainAxisAlignment: MainAxisAlignment.center,
//                    children: [
//                      if (playing) pauseButton() else playButton(),
//                    ],
//                  ),
//                  positionIndicator(mediaItem, state),
//                  Text("Processing state: " +
//                      "$processingState".replaceAll(RegExp(r'^.*\.'), '')),
//                  StreamBuilder(
//                    stream: AudioService.customEventStream,
//                    builder: (context, snapshot) {
//                      return Text("custom event: ${snapshot.data}");
//                    },
//                  ),
//                  StreamBuilder<bool>(
//                    stream: AudioService.notificationClickEventStream,
//                    builder: (context, snapshot) {
//                      return Text(
//                        'Notification Click Status: ${snapshot.data}',
//                      );
//                    },
//                  ),
//                ],
//              ],
//            );
        },
      ),
    );
  }

  void getArtUrl(MediaItem mediaItem) {
    if (artUrl == null && mediaItem != null && mediaItem.artUri.isNotEmpty) {
      artUrl = mediaItem.artUri;
    }
  }

  void getCoverColor(MediaItem mediaItem) {
    if (coverColorAsColor == null && mediaItem != null) {
      final coverColor = mediaItem?.extras['coverColor'];
      coverColorAsColor = parseColor(coverColor);
    }
  }

  void getTextColor(MediaItem mediaItem) {
    if (textColor == null && mediaItem != null) {
      String textColorString = mediaItem?.extras['textColor'];

      if (textColorString.isEmpty) {
        textColorString = "#FF272829";
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarIconBrightness:  Brightness.dark,
        ));
      }
      textColor = parseColor(textColorString);
    }
  }

  Widget buildCircularIndicatorRow() {
    return Expanded(
      child: Container(
        height: 56,
        decoration: buildBoxDecoration(MeditoColors.moonlight),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(backgroundColor: Colors.white)),
        ),
      ),
    );
  }

  BoxDecoration buildBoxDecoration(Color color) {
    return new BoxDecoration(
        color: color,
        borderRadius: new BorderRadius.all(
          const Radius.circular(12.0),
        ));
  }

  Widget getPlayingOrPausedButton(bool playing) {
    return playing ? pauseButton() : playButton();
  }

  /// Encapsulate all the different data we're interested in into a single
  /// stream so we don't have to nest StreamBuilders.
  Stream<ScreenState> get _screenStateStream =>
      Rx.combineLatest3<List<MediaItem>, MediaItem, PlaybackState, ScreenState>(
          AudioService.queueStream,
          AudioService.currentMediaItemStream,
          AudioService.playbackStateStream,
          (queue, mediaItem, playbackState) =>
              ScreenState(queue, mediaItem, playbackState));

  Widget playButton() => PlayerButton(
        icon: Icons.play_arrow,
        onPressed: AudioService.play,
        bgColor: MeditoColors.moonlight,
      );

  Widget pauseButton() => PlayerButton(
        icon: Icons.pause,
        onPressed: AudioService.pause,
        bgColor: MeditoColors.moonlight,
      );

  Widget positionIndicator(
      MediaItem mediaItem, PlaybackState state, Color coverColorAsColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: PositionIndicatorWidget(
          mediaItem: mediaItem, state: state, color: coverColorAsColor),
    );
  }

  void _onBackPressed() {
    Navigator.popUntil(context, ModalRoute.withName("/nav"));
  }

  Widget getDonateAndShareButton() {
    return Column(
      children: <Widget>[
        PlayerButton(
            image: SvgPicture.asset(
              buttonIcon,
              color: textColor,
            ),
            onPressed: _launchDonate,
            bgColor: coverColorAsColor,
            text: buttonLabel,
            textColor: textColor),
        Container(height: 8),
        PlayerButton(
          bgColor: MeditoColors.moonlight,
          icon: Icons.share,
          onPressed: _share,
          text: "Share",
          textColor: Colors.white,
        )
      ],
    );
  }

  Future<void> _launchDonate() {
    getVersionCopyInt().then((version) {
      Tracking.trackEvent(
          Tracking.PLAYER, Tracking.BUTTON_TAPPED, Tracking.AUDIO_COMPLETED,
          map: {'version_seen': 'version_$version'});
      return null;
    });
    return launchUrl(buttonUrl);
  }

  Future<void> _share() {
    Share.share(
        "I just meditated with Medito. I ❤️ this app! Try it out - it's 100% free! Download on Android -> bit.ly/medito-android & iOS -> bit.ly/medito-ios");
    Tracking.trackEvent(
      Tracking.PLAYER,
      Tracking.SHARE_BUTTON_TAPPED,
      Tracking.AUDIO_COMPLETED,
    );
    return null;
  }
}

class PlayerButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color bgColor;
  final String text;
  final Color textColor;
  final SvgPicture image;

  PlayerButton(
      {Key key,
      this.icon,
      this.onPressed,
      this.bgColor,
      this.text,
      this.textColor,
      this.image})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      height: 56.0,
      child: FlatButton(
          color: bgColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              image != null
                  ? image
                  : Icon(
                      icon,
                      size: 24,
                      color: text ==
                              null //usually if there is no text it'll just be a play/pause button
                          ? Colors.white
                          : textColor,
                    ),
              text == null
                  ? Container()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        text,
                        style: Theme.of(context)
                            .textTheme
                            .subtitle1
                            .copyWith(color: textColor),
                      ),
                    )
            ],
          ),
          onPressed: onPressed),
    );
  }
}

class PositionIndicatorWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final PlaybackState state;
  final Color color;

  PositionIndicatorWidget({Key key, this.state, this.mediaItem, this.color})
      : super(key: key);

  @override
  _PositionIndicatorWidgetState createState() =>
      _PositionIndicatorWidgetState();
}

class _PositionIndicatorWidgetState extends State<PositionIndicatorWidget> {
  double position;

  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double> _dragPositionSubject =
      BehaviorSubject.seeded(null);
  var millisecondsListened = 0;
  var _updatedStats = false;

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness:  Brightness.light,
    ));
    updateMinuteCounter(Duration(milliseconds: millisecondsListened).inSeconds);
    millisecondsListened = 0;
  }

  void setBgVolumeFadeAtEnd(
      MediaItem mediaItem, int positionSecs, int durSecs) {
    millisecondsListened += 200;
    var timeLeft = durSecs - positionSecs;
    if (timeLeft <= 10) {
      AudioService.customAction('bgVolume', timeLeft);
    }
    if (timeLeft < 5 && !_updatedStats) {
      markAsListened(mediaItem.extras['id']);
      incrementNumSessions();
      updateStreak();
      _updatedStats = true;
      getVersionCopyInt().then((version) {
        Tracking.trackEvent(
            Tracking.PLAYER, Tracking.PLAYER_TAPPED, Tracking.AUDIO_COMPLETED,
            map: {
              'version_seen': 'version_$version',
              'session_id': mediaItem.id
            });
        return null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double seekPos;
    return StreamBuilder(
      stream: Rx.combineLatest2<double, double, double>(
          _dragPositionSubject.stream,
          Stream.periodic(Duration(milliseconds: 200)),
          (dragPosition, _) => dragPosition),
      builder: (context, snapshot) {
        double position = snapshot.data ??
            widget.state?.currentPosition?.inMilliseconds?.toDouble() ??
            0;
        int duration = widget.mediaItem?.duration?.inMilliseconds ?? 0;

        if (duration > 0 && position > 0) {
          setBgVolumeFadeAtEnd(
              widget.mediaItem,
              widget.state?.currentPosition?.inSeconds ?? 0,
              widget.mediaItem?.duration?.inSeconds);
        }

        return Column(
          children: [
            if (duration != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackShape: CustomTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
                  ),
                  child: Slider(
                    min: 0.0,
                    activeColor: widget.color,
                    inactiveColor: MeditoColors.newGrey,
                    max: duration.toDouble(),
                    value: seekPos ??
                        max(0.0, min(position.toDouble(), duration.toDouble())),
                    onChanged: (value) {
                      _dragPositionSubject.add(value);
                    },
                    onChangeEnd: (value) {
                      AudioService.seekTo(
                          Duration(milliseconds: value.toInt()));
                      seekPos = value;
                      _dragPositionSubject.add(null);
                    },
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      Duration(
                              milliseconds: widget
                                      .state?.currentPosition?.inMilliseconds ??
                                  0)
                          .toMinutesSeconds(),
                      style: Theme.of(context)
                          .textTheme
                          .headline1
                          .copyWith(color: MeditoColors.newGrey)),
                  Text(
                    Duration(milliseconds: duration).toMinutesSeconds(),
                    style: Theme.of(context)
                        .textTheme
                        .headline1
                        .copyWith(color: MeditoColors.newGrey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScreenState {
  final List<MediaItem> queue;
  final MediaItem mediaItem;
  final PlaybackState playbackState;

  ScreenState(this.queue, this.mediaItem, this.playbackState);
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player = new AudioPlayer();
  AudioPlayer _bgPlayer = new AudioPlayer();
  AudioProcessingState _skipState;
  Seeker _seeker;
  StreamSubscription<PlaybackEvent> _eventSubscription;
  var _duration = Duration();

  int get index => _player.currentIndex;
  MediaItem mediaItem;
  var initialBgVolume = 0.4;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    await MediaLibrary.retrieveMediaLibrary().then((value) {
      this.mediaItem = value;
    });

    // Load and broadcast the queue
    AudioServiceBackground.setQueue([mediaItem]);
    try {
      await getDownload(mediaItem.extras['location']).then((data) async {
        if (data == null) {
          _duration = await _player.setUrl(mediaItem.id);
        } else {
          _duration = await _player.setFilePath(data);
        }

        playBgMusic(mediaItem.extras['bgMusic']);
        onPlay();
      });
    } catch (e) {
      print("Error: $e");
      onStop();
    }

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null)
        AudioServiceBackground.setMediaItem(
            mediaItem.copyWith(duration: _duration));
      return null;
    });
    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });
    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          // In this example, the service stops when reaching the end.
          onStop();
          break;
        case ProcessingState.ready:
          // If we just came from skipping between tracks, clear the skip
          // state now that we're ready to play.
          _skipState = null;
          break;
        default:
          break;
      }
    });
  }

  @override
  Future<void> onPlay() {
    _bgPlayer.play();
    return _player.play();
  }

  @override
  Future<void> onPause() {
    _bgPlayer.pause();
    return _player.pause();
  }

  @override
  Future<void> onSeekTo(Duration position) => _player.seek(position);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekForward(bool begin) async => _seekContinuously(begin, 1);

  @override
  Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  @override
  Future<dynamic> onCustomAction(String name, dynamic arguments) {
    if (name == 'bgVolume') {
      print(arguments.toString());
      _bgPlayer.setVolume(initialBgVolume * (arguments * .1));
    }
    return null;
  }

  @override
  Future<void> onStop() async {
    await _player.pause();
    await _player.dispose();
    await _bgPlayer.pause();
    await _bgPlayer.dispose();
    _eventSubscription.cancel();
    // It is important to wait for this state to be broadcast before we shut
    // down the task. If we don't, the background task will be destroyed before
    // the message gets sent to the UI.
    await _broadcastState();
    // Shut down this task
    await super.onStop();
  }

  /// Jumps away from the current position by [offset].
  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _player.position + offset;
    // Make sure we don't jump out of bounds.
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
    // Perform the jump via a seek.
    await _player.seek(newPosition);
  }

  /// Begins or stops a continuous seek in [direction]. After it begins it will
  /// continue seeking forward or backward by 10 seconds within the audio, at
  /// intervals of 1 second in app time.
  void _seekContinuously(bool begin, int direction) {
    _seeker?.stop();
    if (begin) {
      _seeker = Seeker(_player, Duration(seconds: 10 * direction),
          Duration(seconds: 1), mediaItem)
        ..start();
    }
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: [
        MediaAction.seekTo,
      ],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  /// Maps just_audio's processing state into into audio_service's playing
  /// state. If we are in the middle of a skip, we use [_skipState] instead.
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    switch (_player.processingState) {
      case ProcessingState.none:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }

  void playBgMusic(String bgMusic) {
    if (bgMusic != null && bgMusic.isNotEmpty && bgMusic != "null") {
      _bgPlayer.setFilePath(bgMusic);
      _bgPlayer.setVolume(initialBgVolume);
      _bgPlayer.setLoopMode(LoopMode.one);
    }
  }
}

/// An object that performs interruptable sleep.
class Sleeper {
  Completer _blockingCompleter;

  /// Sleep for a duration. If sleep is interrupted, a
  /// [SleeperInterruptedException] will be thrown.
  Future<void> sleep([Duration duration]) async {
    _blockingCompleter = Completer();
    if (duration != null) {
      await Future.any([Future.delayed(duration), _blockingCompleter.future]);
    } else {
      await _blockingCompleter.future;
    }
    final interrupted = _blockingCompleter.isCompleted;
    _blockingCompleter = null;
    if (interrupted) {
      throw SleeperInterruptedException();
    }
  }

  /// Interrupt any sleep that's underway.
  void interrupt() {
    if (_blockingCompleter?.isCompleted == false) {
      _blockingCompleter.complete();
    }
  }
}

class SleeperInterruptedException {}

class Seeker {
  final AudioPlayer player;
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(
    this.player,
    this.positionInterval,
    this.stepInterval,
    this.mediaItem,
  );

  start() async {
    _running = true;
    while (_running) {
      Duration newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  stop() {
    _running = false;
  }
}

Future<bool> start(String coverColor) {
  int color = getColorFromHex(coverColor);
  AudioService.connect();
  return AudioService.start(
    backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
    androidNotificationChannelName: 'Audio Service Demo',
    // Enable this if you want the Android service to exit the foreground state on pause.
    //androidStopForegroundOnPause: true,
    androidNotificationColor: color,
    androidNotificationIcon: 'drawable/logo',
    androidEnableQueue: true,
  );
}

extension DurationExtensions on Duration {
  /// Converts the duration into a readable string
  /// 15:35
  String toMinutesSeconds() {
    String twoDigitMinutes = _toTwoDigits(this.inMinutes.remainder(60));
    String twoDigitSeconds = _toTwoDigits(this.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _toTwoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
