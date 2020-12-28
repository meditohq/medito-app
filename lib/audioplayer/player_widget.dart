import 'dart:async';

import 'package:Medito/audioplayer/player_button.dart';
import 'package:Medito/audioplayer/position_indicator_widget.dart';
import 'package:Medito/audioplayer/screen_state.dart';
import 'package:Medito/audioplayer/subtitle_text_widget.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/audio_complete_copy_provider.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:Medito/widgets/in_app_review_widget.dart';
import 'package:Medito/widgets/streak_tiles_utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_player_service.dart';

class PlayerWidget extends StatefulWidget {
  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String titleText = 'Loading...';
  String subTitleText = 'Please wait...';
  String buttonLabel = 'Donate';
  String buttonUrl = 'http://meditofoundation.org/donate';
  String buttonIcon = 'assets/images/ic_gift.svg';
  String illustrationUrl;
  Color secondaryColor;
  Color primaryColorAsColor;
  bool _complete = false;
  double _height = 0;
  String __loaded;
  double volume;
  var prefs;

  BuildContext _scaffoldContext;

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

  void initBgVol() async {
    volume = await initSFAndReturnBgVol() ?? 100;
    _dragBgVolumeSubject.add(volume);
    await AudioService.customAction('setBgVolume', volume / 100);
  }

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.PLAYER_PAGE);

    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.black));
    initBgVol();
    _stream = AudioService.customEventStream.listen((event) async {
      if (event == 'stats') {
        await updateStatsFromBg();
      }

      await _stream.cancel();
      return true;
    });

    var provider = AudioCompleteCopyProvider();

    provider.fetchCopy().then((value) {
      if (value != null) {
        titleText = value.title;
        subTitleText = value.subtitle;
        buttonLabel = value.buttonLabel;
        buttonUrl = value.buttonDestination;
        buttonIcon = buttonIcon.replaceFirst('ic_gift', value.buttonIcon);
      } else {
        defaultText();
      }
      return null;
    }).catchError((onError) => defaultText());
  }

  @override
  Widget build(BuildContext context) {
    if (_height == 0) {
      _height = MediaQuery.of(context).size.height;
    }

    return Scaffold(
        backgroundColor: MeditoColors.midnight,
        body: Builder(builder: (BuildContext context) {
          _scaffoldContext = context;
          return StreamBuilder<ScreenState>(
              stream: _screenStateStream,
              builder: (context, snapshot) {
                final screenState = snapshot.data;
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
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          mediaItem?.title ?? titleText,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1
                                              .copyWith(
                                                  letterSpacing: 0.2,
                                                  height: 1.5,
                                                  color: Colors.white,
                                                  fontSize: 20.0,
                                                  fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 32.0, right: 32.0),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        mediaItem?.extras != null
                                            ? SubtitleTextWidget(
                                                mediaItem: mediaItem)
                                            : Expanded(
                                                child: Text(
                                                  subTitleText,
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline1
                                                      .copyWith(
                                                          fontSize: 14.0,
                                                          letterSpacing: 0.2,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: MeditoColors
                                                              .walterWhite
                                                              .withOpacity(0.7),
                                                          height: 1.5),
                                                ),
                                              ),
                                      ]),
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
                      Align(
                          alignment: Alignment.topRight,
                          child: getBgVolumeController(mediaItem))
                    ],
                  ),
                );
              });
        }));
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

  Widget getBgVolumeController(MediaItem mediaItem) => mediaItem == null
      ? Container()
      : mediaItem.extras['bgMusic'] != null
          ? _complete
              ? Container()
              : Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                      icon: StreamBuilder<Object>(
                          stream: _dragBgVolumeSubject,
                          builder: (context, snapshot) {
                            volume = _dragBgVolumeSubject.value;
                            var volumeIcon = volumeIconFunction(volume);

                            return Icon(volumeIcon, color: Colors.white);
                          }),
                      onPressed: () {
                        showDialog(
                            context: context,
                            child: AlertDialog(
                              shape: roundedRectangleBorder(),
                              backgroundColor: MeditoColors.darkBGColor,
                              title: Text('Background sound volume',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headline5),
                              content: SizedBox(
                                height: 120,
                                child: StreamBuilder<Object>(
                                    stream: _dragBgVolumeSubject,
                                    builder: (context, snapshot) {
                                      volume = _dragBgVolumeSubject.value;
                                      var volumeIcon =
                                          volumeIconFunction(volume);
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
                                              inactiveColor: MeditoColors
                                                  .walterWhite
                                                  .withOpacity(0.7),
                                              max: 100.0,
                                              value: volume,
                                              onChanged: (value) {
                                                _dragBgVolumeSubject.add(value);
                                                AudioService.customAction(
                                                    'setBgVolume', value / 100);
                                              },
                                              onChangeEnd: (value) {
                                                saveBgVolToSF(value);
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
                                  child: FlatButton(
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
                            ));
                      },
                      color: primaryColorAsColor))
          : Container();

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
              ? Image.network(illustrationUrl)
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
        Text('Buffering')
      ],
    ));
  }

  void getArtUrl(MediaItem mediaItem) {
    if (illustrationUrl == null &&
        mediaItem != null &&
        mediaItem.artUri.isNotEmpty) {
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
      child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColorAsColor),
            backgroundColor: secondaryColor,
          )),
      primaryColor: primaryColorAsColor,
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
    if (mediaItem != null) {
      Navigator.popUntil(context, ModalRoute.withName('/nav'));
    } else {
      Navigator.pop(context);
    }
  }

  Widget getDonateAndShareButton() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: 32.0, top: 32, bottom: 8, right: 32.0),
            child: buttonUrl.contains('review')
                ? InAppReviewWidget(thumbsdown: _thanksPopUp)
                : FlatButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    onPressed: _launchPrimaryButton,
                    color: primaryColorAsColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          buttonIcon,
                          color: secondaryColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            buttonLabel,
                            style:
                                TextStyle(color: secondaryColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0),
            child: FlatButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.all(16.0),
              onPressed: _share,
              color: MeditoColors.moonlight,
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

  void _thanksPopUp() {
    createSnackBarWithColor('Thanks for the feedback!', _scaffoldContext,
        MeditoColors.peacefulBlue);
    addCurrentDateToSF('UserDeclinedRating');
    Future.delayed(Duration(seconds: 3))
        .then((value) => Navigator.pop(context));
  }

  Future<void> _launchPrimaryButton() {
    getVersionCopyInt().then((version) {
      Tracking.trackEvent(
          Tracking.CTA_TAPPED, Tracking.MAIN_CTA_TAPPED, buttonUrl,
          map: {'version_seen': '$version'});
      return null;
    });
    if (buttonUrl.contains('medito-donate')) {
      launchDonatePageOrWidget(context);
    } else {
      return launchUrl(buttonUrl);
    }

    return null;
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

  void defaultText() {
    titleText = 'Well done for taking time for yourself!';
    subTitleText =
        'Taking care of yourself is important. We’re here to help you do it, for free, forever.';
    buttonLabel = 'Donate';
    buttonUrl = 'http://meditofoundation.org/donate';
    buttonIcon = 'assets/images/ic_gift.svg';
  }
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  unawaited(AudioServiceBackground.run(() => AudioPlayerTask()));
}

Future<void> start(MediaItem media, String primaryColor) async {
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
  ));
}
