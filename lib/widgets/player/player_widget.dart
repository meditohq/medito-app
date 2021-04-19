import 'dart:async';

import 'package:Medito/audioplayer/audio_player_service.dart';
import 'package:Medito/audioplayer/screen_state.dart';
import 'package:Medito/network/player/audio_complete_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:Medito/widgets/player/player_button.dart';
import 'package:Medito/widgets/player/position_indicator_widget.dart';
import 'package:Medito/widgets/player/subtitle_text_widget.dart';
import 'package:Medito/widgets/streak_tile_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';

class PlayerWidget extends StatefulWidget {
  final normalPop;

  PlayerWidget({this.normalPop});

  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String illustrationUrl;
  Color secondaryColor;
  Color primaryColorAsColor;
  bool _complete = false;
  double _height = 0;
  String __loaded;
  double volume;

  AudioCompleteCopyBloc _bloc;

  bool get loaded => __loaded == 'true';

  void setLoaded(bool b) {
    if (__loaded == null && b == true) __loaded = 'true';
  }

  StreamSubscription _stream;

  @override
  void dispose() {
    try {
      AudioService.stop();
    } catch (e) {
      print('stop error!');
    }
    super.dispose();
  }

  void initBgVolume() async {
    volume = await retrieveSavedBgVolume();
    _dragBgVolumeSubject.add(volume);
    if (AudioService.running) {
      await AudioService.customAction('setBgVolume', volume / 100);
    }
  }

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.PLAYER_PAGE);

    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.black));

    initBgVolume();

    _stream = AudioService.customEventStream.listen((event) async {
      if (event == 'stats') {
        await updateStatsFromBg();
      }
      await _stream.cancel();
      return true;
    });

    _bloc = AudioCompleteCopyBloc();
  }

  @override
  Widget build(BuildContext context) {
    if (_height == 0) {
      _height = MediaQuery.of(context).size.height;
    }

    return Scaffold(
        backgroundColor: MeditoColors.midnight,
        body: Builder(builder: (BuildContext context) {
          return StreamBuilder<ScreenState>(
              stream: _screenStateStream,
              builder: (context, screenStateSnapshot) {
                final screenState = screenStateSnapshot.data;
                final mediaItem = screenState?.mediaItem;
                final state = screenState?.playbackState;
                final processingState =
                    state?.processingState ?? AudioProcessingState.none;
                final playing = state?.playing ?? false;

                if (processingState == AudioProcessingState.stopped ||
                    processingState == AudioProcessingState.completed ||
                    (loaded && mediaItem == null)) {
                  _complete = true;
                  Tracking.changeScreenName(Tracking.PLAYER_END_PAGE);
                }

                setLoaded(mediaItem != null);
                getSecondaryColor(mediaItem);
                getPrimaryColor(mediaItem);
                getArtUrl(mediaItem);

                return SafeArea(
                  child: Stack(
                    children: [
                      GradientWidget(
                          primaryColor: primaryColorAsColor, height: 350.0),
                      (mediaItem != null || _complete)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                getBigImage(),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 24.0,
                                      left: 32.0,
                                      bottom: 4.0,
                                      right: 32.0),
                                  child: buildTitleRow(mediaItem),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 32.0, right: 32.0),
                                  child: getSubtitleWidget(mediaItem),
                                ),
                                _complete
                                    ? getDonateAndShareButton()
                                    : buildPlayingPauseOrLoadingIndicator(
                                        processingState, playing),
                                _complete
                                    ? Container()
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            left: 24.0,
                                            right: 24.0,
                                            top: 10.0,
                                            bottom: 32.0),
                                        child: positionIndicator(mediaItem,
                                            state, primaryColorAsColor),
                                      ),
                              ],
                            )
                          : buildLoadingScreenWidget(),
                      SafeArea(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4.0, top: 4.0),
                          child: IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => _onBackPressed(mediaItem),
                            color: MeditoColors.walterWhite,
                          ),
                        ),
                      ),
                      loaded
                          ? Align(
                              alignment: Alignment.topRight,
                              child: _complete
                                  ? Container()
                                  : getBgVolumeController(mediaItem))
                          : Container()
                    ],
                  ),
                );
              });
        }));
  }

  Row buildTitleRow(MediaItem mediaItem) {
    return Row(
      children: [
        Expanded(
            child: !_complete
                ? Text(
                    mediaItem?.title ?? 'Loading...',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildTitleTheme(),
                  )
                : FutureBuilder<String>(
                    future: _bloc.getVersionTitle(),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.hasData ? snapshot.data : 'Loading...',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildTitleTheme(),
                      );
                    })),
      ],
    );
  }

  TextStyle buildTitleTheme() {
    return Theme.of(context).textTheme.headline1;
  }

  StatelessWidget getSubtitleWidget(MediaItem mediaItem) {
    var attr = '';
    if (_complete) {
      attr = _bloc.version.body;
    } else {
      attr = mediaItem?.extras != null ? mediaItem?.extras['attr'] : '';
    }

    return loaded ? SubtitleTextWidget(body: attr) : Container();
  }

  IconData volumeIconFunction(var volume) {
    if (volume == 0) {
      return Icons.volume_off;
    } else if (volume < 50) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  void _onCancelTap() {
    Navigator.pop(context);
  }

  /// Tracks the bgVolume while the user drags the bgVolume bar.
  final BehaviorSubject<double> _dragBgVolumeSubject =
      BehaviorSubject.seeded(null);

  Widget getBgVolumeController(MediaItem mediaItem) {
    if ((mediaItem?.extras['bgMusic'] as String)?.isNotEmptyAndNotNull() ??
        false) {
      return Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 8),
          child: IconButton(
              icon: StreamBuilder<Object>(
                  stream: _dragBgVolumeSubject,
                  builder: (context, snapshot) {
                    volume = _dragBgVolumeSubject.value;
                    var volumeIcon = volumeIconFunction(volume);

                    return Icon(volumeIcon,
                        semanticLabel: 'Change volume button',
                        color: Colors.white);
                  }),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: roundedRectangleBorder(),
                        backgroundColor: MeditoColors.darkBGColor,
                        title: Text('Background sound volume',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headline2),
                        content: SizedBox(
                          height: 120,
                          child: StreamBuilder<Object>(
                              stream: _dragBgVolumeSubject,
                              builder: (context, snapshot) {
                                volume = _dragBgVolumeSubject.value;
                                var volumeIcon = volumeIconFunction(volume);
                                return Column(
                                  children: [
                                    SizedBox(height: 24),
                                    Icon(volumeIcon,
                                        size: 30,
                                        color: MeditoColors.walterWhite),
                                    SizedBox(height: 16),
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackShape: CustomTrackShape(),
                                        thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius: 10.0),
                                      ),
                                      child: Slider(
                                        min: 0.0,
                                        activeColor: primaryColorAsColor,
                                        inactiveColor: MeditoColors.walterWhite
                                            .withOpacity(0.7),
                                        max: 100.0,
                                        value: volume,
                                        onChanged: (value) {
                                          _dragBgVolumeSubject.add(value);
                                          AudioService.customAction(
                                              'setBgVolume', value / 100);
                                        },
                                        onChangeEnd: (value) {
                                          saveBgVolume(value);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }),
                        ),
                        actions: [
                          Container(
                            height: 48,
                            child: TextButton(
                              onPressed: _onCancelTap,
                              child: Text(
                                'CANCEL',
                                style: Theme.of(context)
                                    .textTheme
                                    .headline3
                                    .copyWith(
                                        color: MeditoColors.walterWhite,
                                        fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      );
                    });
              },
              color: primaryColorAsColor));
    } else {
      return Container();
    }
  }

  Padding getBigImage() {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 64.0),
      child: Container(
        constraints: BoxConstraints(maxHeight: _height / 3, maxWidth: 1000),
        decoration: BoxDecoration(
            color: primaryColorAsColor,
            borderRadius: BorderRadius.circular(12.0)),
        padding: EdgeInsets.all(48.0),
        child: Center(
          child: illustrationUrl != null
              ? getNetworkImageWidget(illustrationUrl)
              : Container(),
        ),
      ),
    );
  }

  Expanded buildPlayingPauseOrLoadingIndicator(
      AudioProcessingState processingState, bool playing) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (processingState == AudioProcessingState.buffering ||
                  processingState == AudioProcessingState.connecting)
              ? buildCircularIndicatorRow()
              : getPlayingOrPausedButton(playing),
        ],
      ),
    );
  }

  Center buildLoadingScreenWidget() {
    return Center(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        Container(height: 16),
        Text('Loading')
      ],
    ));
  }

  void getArtUrl(MediaItem mediaItem) {
    if (illustrationUrl == null &&
        mediaItem != null &&
        mediaItem.artUri.isNotEmptyAndNotNull()) {
      illustrationUrl = mediaItem.artUri;
    }
  }

  void getPrimaryColor(MediaItem mediaItem) {
    if (primaryColorAsColor == null && mediaItem != null) {
      final primaryColor = mediaItem?.extras['primaryColor'];
      primaryColorAsColor = parseColor(primaryColor);
    }
  }

  void getSecondaryColor(MediaItem mediaItem) {
    if (secondaryColor == null && mediaItem != null) {
      String secondaryColorString = mediaItem?.extras['secondaryColor'] ?? '';

      if (secondaryColorString.isEmpty && secondaryColor == null) {
        secondaryColorString = '#FF272829';
      }
      secondaryColor = parseColor(secondaryColorString);
    }
  }

  Widget buildCircularIndicatorRow() {
    return PlayerButton(
      primaryColor: primaryColorAsColor,
      child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColorAsColor),
            backgroundColor: secondaryColor,
          )),
    );
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

  Widget playButton() => Semantics(
        label: 'Play button',
        child: PlayerButton(
          icon: Icons.play_arrow,
          onPressed: AudioService.play,
          secondaryColor: secondaryColor,
          primaryColor: primaryColorAsColor,
        ),
      );

  Widget pauseButton() => Semantics(
        label: 'Pause button',
        child: PlayerButton(
          icon: Icons.pause,
          secondaryColor: secondaryColor,
          onPressed: AudioService.pause,
          primaryColor: primaryColorAsColor,
        ),
      );

  Widget positionIndicator(
      MediaItem mediaItem, PlaybackState state, Color primaryColorAsColor) {
    return PositionIndicatorWidget(
        mediaItem: mediaItem, state: state, color: primaryColorAsColor);
  }

  void _onBackPressed(MediaItem mediaItem) {
    if (mediaItem == null || (widget.normalPop != null && widget.normalPop)) {
      Navigator.pop(context);
    } else {
      Navigator.popUntil(
          context,
          (Route<dynamic> route) =>
              route.settings.name == FolderNavWidget.routeName ||
              route.isFirst);
    }
  }

  Widget getDonateAndShareButton() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: 32.0, top: 32, bottom: 8, right: 32.0),
            child: TextButton(
              style: TextButton.styleFrom(
                  shape: roundedRectangleBorder(),
                  backgroundColor: primaryColorAsColor,
                  padding: const EdgeInsets.all(16.0)),
              onPressed: () => _launchPrimaryButton(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildSvgPicture(),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: buildButtonLabel(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0),
            child: TextButton(
              style: TextButton.styleFrom(
                  shape: roundedRectangleBorder(),
                  backgroundColor: MeditoColors.moonlight,
                  padding: const EdgeInsets.all(16.0)),
              onPressed: _share,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share, color: MeditoColors.walterWhite),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Share',
                      style: TextStyle(
                          color: MeditoColors.walterWhite, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildButtonLabel() {
    var label = _bloc.version?.buttonLabel;

    if (label == null) return Container();

    return Text(
      label,
      style: TextStyle(color: secondaryColor, fontSize: 16),
    );
  }

  Widget buildSvgPicture() {
    var icon = _bloc.version?.buttonIcon;

    if (icon == null) return Container();

    return SvgPicture.asset(
      'assets/images/' + icon + '.svg',
      color: secondaryColor,
    );
  }

  Future<void> _launchPrimaryButton() {
    var path = _bloc.version.buttonPath;

    getVersionCopyInt().then((version) {
      Tracking.trackEvent(Tracking.CTA_TAPPED, Tracking.MAIN_CTA_TAPPED, path,
          map: {'version_seen': '$version'});
    });

    return launchUrl(path);
  }

  Future<void> _share() {
    Share.share(
        "I just meditated with Medito. I ❤️ this app! Try it out - it's 100% free! Download on Android -> https://bit.ly/medito-android & iOS -> https://bit.ly/medito-ios");
    Tracking.trackEvent(
      Tracking.CTA_TAPPED,
      Tracking.SECOND_CTA_TAPPED,
      '',
    );
    return null;
  }
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  unawaited(AudioServiceBackground.run(() => AudioPlayerTask()));
}

Future<void> start(MediaItem media) async {
  var map = {'media': media.toJson()};
  unawaited(AudioService.connect());
  unawaited(AudioService.start(
    params: map,
    backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
    androidNotificationChannelName: 'Medito Audio Service',
    // Enable this if you want the Android service to exit the foreground state on pause.
    //androidStopForegroundOnPause: true,
    androidNotificationIcon: 'drawable/logo',
    androidEnableQueue: true,
  ).onError((error, stackTrace) => _printError(error)));
}

FutureOr<bool> _printError(error) async {
  print(error);
  return true;
}

bool checkDaysSinceReview() {
  var days = 365;
  daysSinceDate('UserDeclinedReview').then((value) => days = value);
  return days > 28;
}
