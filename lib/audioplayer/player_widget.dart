import 'dart:async';

import 'package:Medito/audioplayer/player_button.dart';
import 'package:Medito/audioplayer/position_indicator_widget.dart';
import 'package:Medito/audioplayer/screen_state.dart';
import 'package:Medito/audioplayer/subtitle_text_widget.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/audio_complete_copy_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';

import 'audio_player_service.dart';

class PlayerWidget extends StatefulWidget {
  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  String titleText = "Loading...";
  String subTitleText = "Please wait...";
  String buttonLabel = "";
  String buttonUrl = "http://meditofoundation.org/donate";
  String buttonIcon = "";
  String artUrl;
  Color secondaryColor;
  Color primaryColorAsColor;

  StreamSubscription _stream;

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

    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.black));

    _stream = AudioService.customEventStream
        .asBroadcastStream()
        .listen((params) async {
      await updateStatsFromBg();
      _stream.cancel();
      return true;
    });

    AudioCompleteCopyProvider provider = AudioCompleteCopyProvider();

    provider.fetchCopy().then((value) {
      if (value != null) {
        titleText = value.title;
        subTitleText = value.subtitle;
        buttonLabel = value.buttonLabel;
        buttonUrl = value.buttonDestination;
        buttonIcon = buttonIcon.replaceFirst("ic_gift", value.buttonIcon);
      } else {
        defaultText();
      }
      return null;
    }).catchError((onError) => defaultText());
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

          getSecondaryColor(mediaItem);
          getPrimaryColor(mediaItem);
          getArtUrl(mediaItem);

          return SafeArea(
            child: Stack(
              children: [
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      primaryColorAsColor?.withOpacity(0.6) ?? MeditoColors.moonlight,
                      MeditoColors.midnight,
                    ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                ),
                Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 32.0, right: 32.0, top: 64.0),
                      child: Container(
                        constraints: BoxConstraints(minHeight: 280),
                        decoration: BoxDecoration(
                            color: primaryColorAsColor,
                            borderRadius: BorderRadius.circular(12.0)),
                        padding: EdgeInsets.all(48.0),
                        child: Center(
                          child: artUrl != null
                              ? Image.network(artUrl)
                              : Container(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 24.0, left: 32.0, bottom: 4.0, right: 32.0),
                      child: Text(
                        mediaItem?.title ?? titleText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyText1.copyWith(
                            letterSpacing: 0.2,
                            height: 1.5,
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0, right: 32.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            mediaItem?.extras != null
                                ? SubtitleTextWidget(mediaItem: mediaItem)
                                : Text(
                                    subTitleText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline1
                                        .copyWith(
                                            letterSpacing: 0.2,
                                            fontWeight: FontWeight.w500,
                                            color: MeditoColors.walterWhite
                                                .withOpacity(0.7),
                                            height: 1.5),
                                  ),
                          ]),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          (processingState == AudioProcessingState.buffering ||
                                  processingState ==
                                      AudioProcessingState.connecting)
                              ? buildCircularIndicatorRow()
                              : mediaItem == null
                                  ? getDonateAndShareButton()
                                  : getPlayingOrPausedButton(playing),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 24.0, right: 24.0, bottom: 32.0),
                      child: mediaItem == null
                          ? Container()
                          : positionIndicator(
                              mediaItem, state, primaryColorAsColor),
                    ),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(left: 4.0, top: 4.0),
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: _onBackPressed,
                      color: MeditoColors.walterWhite,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void getArtUrl(MediaItem mediaItem) {
    if (artUrl == null && mediaItem != null && mediaItem.artUri.isNotEmpty) {
      artUrl = mediaItem.artUri;
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
      String secondaryColorString = mediaItem?.extras['secondaryColor'] ?? "";

      if (secondaryColorString.isEmpty && secondaryColor == null) {
        secondaryColorString = "#FF272829";
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
        secondaryColor: secondaryColor,
        primaryColor: primaryColorAsColor,
      );

  Widget pauseButton() => PlayerButton(
        icon: Icons.pause,
        secondaryColor: secondaryColor,
        onPressed: AudioService.pause,
        primaryColor: primaryColorAsColor,
      );

  Widget positionIndicator(
      MediaItem mediaItem, PlaybackState state, Color primaryColorAsColor) {
    return PositionIndicatorWidget(
        mediaItem: mediaItem, state: state, color: primaryColorAsColor);
  }

  void _onBackPressed() {
    Navigator.popUntil(context, ModalRoute.withName("/nav"));
  }

  Widget getDonateAndShareButton() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: PlayerButton(
              image: SvgPicture.asset(
                buttonIcon,
                color: secondaryColor,
              ),
              onPressed: _launchDonate,
              primaryColor: primaryColorAsColor,
              text: buttonLabel,
              secondaryColor: secondaryColor),
        ),
        Container(height: 8),
        PlayerButton(
          primaryColor: MeditoColors.moonlight,
          icon: Icons.share,
          onPressed: _share,
          text: "Share",
          secondaryColor: Colors.white,
        )
      ],
    );
  }

  Future<void> _launchDonate() {
    getVersionCopyInt().then((version) {
      Tracking.trackEvent(Tracking.AUDIO_COMPLETED, Tracking.BUTTON_TAPPED,
          Tracking.AUDIO_COMPLETED,
          map: {'version_seen': '$version'});
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

  void defaultText() {
    titleText = "Well done for taking time for yourself!";
    subTitleText =
        "Taking care of yourself is important. We’re here to help you do it, for free, forever.";
    buttonLabel = "Donate";
    buttonUrl = "http://meditofoundation.org/donate";
    buttonIcon = "assets/images/ic_gift.svg";
  }
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

Future<bool> start(String primaryColor) {
  AudioService.connect();
  return AudioService.start(
    backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
    androidNotificationChannelName: 'Medito Audio Service',
    // Enable this if you want the Android service to exit the foreground state on pause.
    //androidStopForegroundOnPause: true,
    androidNotificationIcon: 'drawable/logo',
    androidEnableQueue: true,
  );
}
