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
import 'package:google_fonts/google_fonts.dart';
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
  Color textColor;
  Color coverColorAsColor;

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

          getTextColor(mediaItem);
          getCoverColor(mediaItem);
          getArtUrl(mediaItem);

          return SafeArea(
            child: Stack(
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
                          top: 28.0, left: 16.0, bottom: 4.0, right: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              mediaItem?.title ?? titleText,
                              style: Theme.of(context).textTheme.bodyText1.copyWith(
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
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                      child: Row(children: [
                        mediaItem?.extras != null
                            ? SubtitleTextWidget(mediaItem: mediaItem)
                            : Expanded(
                                child: Text(
                                subTitleText,
                                style: Theme.of(context)
                                    .textTheme
                                    .headline1
                                    .copyWith(
                                        letterSpacing: 0.2,
                                        fontWeight: FontWeight.w500,
                                        color: MeditoColors.walterWhite.withOpacity(0.7),
                                        height: 1.5),
                              )),
                      ]),
                    ),
                    mediaItem == null
                        ? Container()
                        : positionIndicator(
                            mediaItem, state, coverColorAsColor),
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
                    padding: EdgeInsets.only(left: 4.0, top: 4.0),
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: _onBackPressed,
                      color: textColor,
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

  void getCoverColor(MediaItem mediaItem) {
    if (coverColorAsColor == null && mediaItem != null) {
      final coverColor = mediaItem?.extras['coverColor'];
      coverColorAsColor = parseColor(coverColor);
    }
  }

  void getTextColor(MediaItem mediaItem) {
    if (textColor == null && mediaItem != null) {
      String textColorString = mediaItem?.extras['textColor'];

      if (textColorString.isEmpty && textColor == null) {
        textColorString = "#FF272829";
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
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: PlayerButton(
              image: SvgPicture.asset(
                buttonIcon,
                color: textColor,
              ),
              onPressed: _launchDonate,
              bgColor: coverColorAsColor,
              text: buttonLabel,
              textColor: textColor),
        ),
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
