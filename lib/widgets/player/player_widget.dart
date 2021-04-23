import 'dart:async';

import 'package:Medito/audioplayer/audio_player_service.dart';
import 'package:Medito/audioplayer/screen_state.dart';
import 'package:Medito/network/player/audio_complete_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
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
  Color primaryColorAsColor = MeditoColors.transparent;
  bool _complete = false;
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
    return Scaffold(body: Builder(builder: (BuildContext context) {
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

            return Stack(
              children: [
                _getGradientWidget(mediaItem, context),
                _getGradientOverlayWidget(),
                (mediaItem != null || _complete)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _getAppBar(mediaItem),
                          _getTitleRow(mediaItem),
                          _getSubtitleWidget(mediaItem),
                          _complete
                              ? getDonateAndShareButton()
                              : _getPlayingPauseOrLoadingIndicator(
                                  processingState, playing),
                          _complete
                              ? Container()
                              : positionIndicator(
                                  mediaItem, state, primaryColorAsColor),
                        ],
                      )
                    : _getLoadingScreenWidget(),
              ],
            );
          });
    }));
  }

  Widget _getGradientOverlayWidget() {
    if (!loaded) return Container();
    return Image.asset(
      'assets/images/texture.png',
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      fit: BoxFit.fill,
    );
  }

  Widget _getGradientWidget(MediaItem mediaItem, BuildContext context) {
    if (!loaded || _complete) return Container();
    return Align(
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
              gradient: RadialGradient(
            colors: [
              primaryColorAsColor.withAlpha(178),
              primaryColorAsColor.withAlpha(0),
            ],
            radius: 1.0,
          )),
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
        ));
  }

  MeditoAppBarWidget _getAppBar(MediaItem mediaItem) {
    return MeditoAppBarWidget(
      transparent: true,
      hasCloseButton: true,
      closePressed: _onBackPressed,
      actions: [
        loaded
            ? _complete
                ? Container()
                : _getBgVolumeController(mediaItem)
            : Container()
      ],
    );
  }

  Widget _getTitleRow(MediaItem mediaItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
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
      ),
    );
  }

  TextStyle buildTitleTheme() {
    return Theme.of(context).textTheme.headline1;
  }

  Widget _getSubtitleWidget(MediaItem mediaItem) {
    var attr = '';
    if (_complete) {
      attr = _bloc.version?.body ?? WELL_DONE_SUBTITLE;
    } else {
      attr = mediaItem?.extras != null ? mediaItem?.extras['attr'] : '';
    }

    return loaded
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SubtitleTextWidget(body: attr),
          )
        : Container();
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

  Widget _getBgVolumeController(MediaItem mediaItem) {
    if ((mediaItem?.extras['bgMusic'] as String)?.isNotEmptyAndNotNull() ??
        false) {
      return Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 8),
          child: IconButton(
              icon: StreamBuilder<Object>(
                  stream: _dragBgVolumeSubject,
                  builder: (context, snapshot) {
                    volume = _dragBgVolumeSubject.value;
                    return Icon(Icons.landscape,
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

  Expanded _getPlayingPauseOrLoadingIndicator(
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

  Center _getLoadingScreenWidget() {
    return Center(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        Container(height: 16),
        Text(loaded ? WELL_DONE_COPY : LOADING)
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
    if (mediaItem != null) {
      final primaryColor = mediaItem?.extras['primaryColor'];
      primaryColorAsColor = parseColor(primaryColor);
    }
  }

  void getSecondaryColor(MediaItem mediaItem) {
    if (secondaryColor == null && mediaItem != null) {
      String secondaryColorString = mediaItem?.extras['secondaryColor'] ?? '';

      if (secondaryColorString.isEmptyOrNull()) {
        secondaryColor = MeditoColors.deepNight;
      } else {
        secondaryColor = parseColor(secondaryColorString);
      }
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: PositionIndicatorWidget(
          mediaItem: mediaItem, state: state, color: primaryColorAsColor),
    );
  }

  void _onBackPressed() {
    if (_complete || (widget.normalPop != null && widget.normalPop)) {
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
                left: 16.0, top: 32, bottom: 8, right: 16.0),
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
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
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
                      style: Theme.of(context).textTheme.subtitle2,
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
      style: Theme.of(context)
          .textTheme
          .subtitle2
          .copyWith(color: MeditoColors.darkMoon),
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
    Share.share(SHARE_TEXT);
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
