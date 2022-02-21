/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:async';

import 'package:Medito/audioplayer/audio_player_service.dart';
import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/screen_state.dart';
import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/home/streak_tile_widget.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:Medito/widgets/player/player_button.dart';
import 'package:Medito/widgets/player/position_indicator_widget.dart';
import 'package:Medito/widgets/player/subtitle_text_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';

import 'background_sounds_sheet_widget.dart';

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

  StreamSubscription _stream;
  PlayerBloc _bloc;

  MediaItem _mediaItem;

  bool get loaded => __loaded == 'true';
  String __loaded;
  bool _complete = false;

  void setLoaded(bool b, MediaItem mediaItem) {
    if (__loaded == null && b == true) {
      __loaded = 'true';
      _mediaItem = mediaItem;
    }
  }

  @override
  void dispose() {
    try {
      AudioService.stop();
      _stream.cancel();
    } catch (e) {
      print('stop error!');
    }
    _bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    retrieveSavedBgVolume().then((value) async =>
        await AudioService.customAction(SET_BG_SOUND_VOL, value / 100));

    _stream = AudioService.customEventStream.listen((event) async {
      if (event == STATS) {
        await updateStatsFromBg();
        unawaited(Tracking.trackEvent({
          Tracking.TYPE: Tracking.AUDIO_COMPLETED,
          Tracking.SESSION_ID: _mediaItem.id,
          Tracking.SESSION_TITLE: _mediaItem.title,
          Tracking.SESSION_LENGTH: _mediaItem.extras[LENGTH],
          Tracking.SESSION_VOICE: _mediaItem.artist
        }));
        return true;
      }
    });
    _startTimeout();
    _bloc = PlayerBloc();
  }

  void _startTimeout() {
    var timerMaxSeconds = 20;
    Timer.periodic(Duration(seconds: timerMaxSeconds), (timer) {
      if (!loaded && mounted) {
        createSnackBar(TIMEOUT, context);
      }
      timer.cancel();
    });
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
            }

            setLoaded(mediaItem != null, mediaItem);
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
                                  mediaItem.extras[HAS_BG_SOUND] ?? true,
                                  processingState,
                                  playing),
                          _complete
                              ? Container()
                              : _positionIndicatorRow(
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
              primaryColorAsColor.withAlpha(100),
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

  Expanded _getPlayingPauseOrLoadingIndicator(
      bool hasBgSound, AudioProcessingState processingState, bool playing) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (processingState == AudioProcessingState.buffering ||
                  processingState == AudioProcessingState.connecting)
              ? buildCircularIndicatorRow(hasBgSound)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    getPlayingOrPausedButton(playing, hasBgSound),
                    _getBgMusicIconButton(hasBgSound)
                  ],
                ),
        ],
      ),
    );
  }

  Widget _getBgMusicIconButton(bool visible) {
    return (Visibility(
      visible: visible,
      child: Padding(
        padding: EdgeInsets.only(top: 32),
        child: MaterialButton(
            enableFeedback: true,
            textColor: MeditoColors.walterWhite,
            color: MeditoColors.walterWhiteTrans,
            onPressed: _onBgMusicPressed,
            child: Padding(
              padding: EdgeInsets.only(top: 4),
                child: Row(children: [
              Icon(
                Icons.music_note_outlined,
                color: MeditoColors.walterWhite,
              ),
              Container(width: 8),
              Text(SOUNDS),
              Container(width: 8),
            ]))),
      ),
    ));
  }

  Center _getLoadingScreenWidget() {
    return Center(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
            backgroundColor: Colors.black,
            valueColor:
                AlwaysStoppedAnimation<Color>(MeditoColors.walterWhite)),
        Container(height: 16),
        Text(loaded ? WELL_DONE_COPY : LOADING)
      ],
    ));
  }

  void getArtUrl(MediaItem mediaItem) {
    if (illustrationUrl == null &&
        mediaItem != null &&
        mediaItem.artUri.toString().isNotEmptyAndNotNull()) {
      illustrationUrl = mediaItem.artUri.toString();
    }
  }

  void getPrimaryColor(MediaItem mediaItem) {
    if (mediaItem != null) {
      final primaryColor = mediaItem?.extras[PRIMARY_COLOUR];
      primaryColorAsColor = parseColor(primaryColor);
    }
  }

  void getSecondaryColor(MediaItem mediaItem) {
    if (secondaryColor == null && mediaItem != null) {
      String secondaryColorString = mediaItem?.extras[SECONDARY_COLOUR] ?? '';

      if (secondaryColorString.isEmptyOrNull()) {
        secondaryColor = MeditoColors.deepNight;
      } else {
        secondaryColor = parseColor(secondaryColorString);
      }
    }
  }

  Widget buildCircularIndicatorRow(bool hasBgSound) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerButton(
          primaryColor: primaryColorAsColor,
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColorAsColor),
                backgroundColor: secondaryColor,
              )),
        ),
        _getBgMusicIconButton(hasBgSound)
      ],
    );
  }

  Widget getPlayingOrPausedButton(bool playing, bool hasBgSound) {
    return playing ? pauseButton() : playButton(hasBgSound);
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

  Widget playButton(bool hasBgSound) => Semantics(
        label: 'Play button',
        child: PlayerButton(
          icon: Icons.play_arrow,
          onPressed: () => _playPressed(hasBgSound),
          secondaryColor: secondaryColor,
          primaryColor: primaryColorAsColor,
        ),
      );

  Future<void> _playPressed(bool hasBgSound) async {
    unawaited(AudioService.play());
    if (hasBgSound) await getSavedBgSoundData();
  }

  Widget pauseButton() => Semantics(
        label: 'Pause button',
        child: PlayerButton(
          icon: Icons.pause,
          secondaryColor: secondaryColor,
          onPressed: AudioService.pause,
          primaryColor: primaryColorAsColor,
        ),
      );

  Widget _positionIndicatorRow(
      MediaItem mediaItem, PlaybackState state, Color primaryColorAsColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: PositionIndicatorWidget(
          mediaItem: mediaItem, state: state, color: primaryColorAsColor),
    );
  }

  Future<void> getSavedBgSoundData() async {
    var file = await getBgSoundFileFromSharedPrefs();
    var name = await getBgSoundNameFromSharedPrefs();
    unawaited(AudioService.customAction(SEND_BG_SOUND, name));
    unawaited(AudioService.customAction(PLAY_BG_SOUND, file));
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
          .copyWith(color: secondaryColor ?? MeditoColors.darkMoon),
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
      //todo fix once screen is changed
      // Tracking.trackEvent({
      //   Tracking.TYPE: Tracking.CTA_TAPPED,
      //   Tracking.PLAYER_COPY_VERSION: '$version'
      // });
    });

    return launchUrl(path);
  }

  Future<void> _share() {
    Share.share(SHARE_TEXT);
    // Tracking.trackEvent({Tracking.TYPE: Tracking.SHARE_TAPPED});
    return null;
  }

  void _onBgMusicPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChooseBackgroundSoundDialog(
          stream: _bloc.bgSoundsListController.stream),
    );
    // slight delay incase the cache returns before the sheet opens
    Future.delayed(Duration(milliseconds: 50))
        .then((value) => _bloc.fetchBackgroundSounds());
  }
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  unawaited(AudioServiceBackground.run(() => AudioPlayerTask()));
  unawaited(AudioService.play());
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
