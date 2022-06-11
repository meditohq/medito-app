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

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:Medito/widgets/player/player2/audio_complete_dialog.dart';
import 'package:Medito/widgets/player/player_button.dart';
import 'package:Medito/widgets/player/position_indicator_widget.dart';
import 'package:Medito/widgets/player/subtitle_text_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

import '../../../audioplayer/audio_inherited_widget.dart';
import '../../../tracking/tracking.dart';
import '../background_sounds_sheet_widget.dart';

class PlayerWidget extends StatefulWidget {
  final normalPop;

  PlayerWidget({this.normalPop});

  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {

  MeditoAudioHandler _handler;
  PlayerBloc _bloc;

  @override
  void dispose() {
    _handler.stop();
    _bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startTimeout();
    _bloc = PlayerBloc();
  }

  void _startTimeout() {
    var timerMaxSeconds = 20;
    Timer.periodic(Duration(seconds: timerMaxSeconds), (timer) {
      if (_handler.playbackState.value.processingState ==
              AudioProcessingState.loading &&
          mounted) {
        createSnackBar(TIMEOUT, context);
      }
      timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    _handler = AudioHandlerInheritedWidget.of(context)?.audioHandler;
    var mediaItem = _handler.mediaItem.value;

    if (_handler.mediaItem.value.extras[HAS_BG_SOUND]) getSavedBgSoundData();

    _handler.customEvent.stream.listen((event) {
      if (mounted && event[AUDIO_COMPLETE] == true) {
        _trackSessionEnd(_handler.mediaItem.value);
        showGeneralDialog(
            transitionDuration: Duration(milliseconds: 400),
            context: context,
            barrierColor: MeditoColors.darkMoon,
            pageBuilder: (_,  __, ___) {
              return AudioCompleteDialog(
                  bloc: _bloc, mediaItem: _handler.mediaItem.value);
            });
      }
    });

    return Material(
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            _getGradientWidget(mediaItem, context),
            _getGradientOverlayWidget(),
            Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _getAppBar(mediaItem),
                  // Show media item title
                  StreamBuilder<MediaItem>(
                    stream: _handler.mediaItem,
                    builder: (context, snapshot) {
                      final mediaItem = snapshot.data;
                      return Column(
                        children: [
                          _getTitleRow(mediaItem, false),
                          _getSubtitleWidget(mediaItem, false)
                        ],
                      );
                    },
                  ),
                  Expanded(child: SizedBox.shrink()),
                  StreamBuilder<bool>(
                    stream: _handler.playbackState
                        .map((state) => state.playing)
                        .distinct(),
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (playing)
                                _pauseButton(mediaItem)
                              else
                                _playButton(mediaItem),
                            ],
                          ),
                          _getBgMusicIconButton(
                              mediaItem.extras[HAS_BG_SOUND] ?? true)
                        ],
                      );
                    },
                  ),
                  Expanded(child: SizedBox.shrink()),
                  // A seek bar.
                  PositionIndicatorWidget(
                    handler: _handler,
                    color: parseColor(mediaItem.extras[PRIMARY_COLOUR]),
                  ),
                  Container(height: 24)
                ])
          ],
        ),
      ),
    );
  }

  Widget _getGradientOverlayWidget() {
    return Image.asset(
      'assets/images/texture.png',
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      fit: BoxFit.fill,
    );
  }

  Widget _getGradientWidget(MediaItem mediaItem, BuildContext context) {
    return Align(
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
              gradient: RadialGradient(
            colors: [
              parseColor(mediaItem.extras[PRIMARY_COLOUR]).withAlpha(100),
              parseColor(mediaItem.extras[PRIMARY_COLOUR]).withAlpha(0),
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

  Widget _getTitleRow(MediaItem mediaItem, bool complete) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
              child: !complete
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

  Widget _getSubtitleWidget(MediaItem mediaItem, bool complete) {
    var attr = '';
    if (complete) {
      attr = _bloc.version?.body ?? WELL_DONE_SUBTITLE;
    } else {
      attr = mediaItem?.extras != null ? mediaItem?.extras['attr'] : '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SubtitleTextWidget(body: attr),
    );
  }

  Widget _getBgMusicIconButton(bool visible) {
    return Visibility(
      visible: visible,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
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
        ],
      ),
    );
  }

  Widget _playButton(MediaItem mediaItem) => Semantics(
        label: 'Play button',
        child: PlayerButton(
          icon: Icons.play_arrow,
          onPressed: () => _playPressed(mediaItem.extras[HAS_BG_SOUND] ?? true),
          secondaryColor: parseColor(mediaItem.extras[SECONDARY_COLOUR]),
          primaryColor: parseColor(mediaItem.extras[PRIMARY_COLOUR]),
        ),
      );

  Future<void> _playPressed(bool hasBgSound) async {
    await _handler.play();
    if (hasBgSound) await getSavedBgSoundData();
  }

  Widget _pauseButton(MediaItem mediaItem) => Semantics(
        label: 'Pause button',
        child: PlayerButton(
          icon: Icons.pause,
          secondaryColor: parseColor(mediaItem.extras[SECONDARY_COLOUR]),
          primaryColor: parseColor(mediaItem.extras[PRIMARY_COLOUR]),
          onPressed: _handler.pause,
        ),
      );

  Future<void> getSavedBgSoundData() async {
    var file = await getBgSoundFileFromSharedPrefs();
    var name = await getBgSoundNameFromSharedPrefs();
    unawaited(_handler.customAction(SEND_BG_SOUND, {SEND_BG_SOUND: name}));
    unawaited(_handler.customAction(PLAY_BG_SOUND, {PLAY_BG_SOUND: file}));
  }

  void _onBackPressed() {
    GoRouter.of(context).pop();
  }

  Widget buildButtonLabel(MediaItem mediaItem) {
    var label = _bloc.version?.buttonLabel;

    if (label == null) return Container();

    return Text(
      label,
      style: Theme.of(context).textTheme.subtitle2.copyWith(
          color: parseColor(mediaItem.extras[SECONDARY_COLOUR]) ??
              MeditoColors.darkMoon),
    );
  }

  Widget buildSvgPicture(Color secondaryColor) {
    var icon = _bloc.version?.buttonIcon;

    if (icon == null) return Container();

    return SvgPicture.asset(
      'assets/images/' + icon + '.svg',
      color: secondaryColor,
    );
  }

  void _trackSessionEnd(MediaItem mediaItem) {
    unawaited(Tracking.trackEvent({
      Tracking.TYPE: Tracking.AUDIO_COMPLETED,
      Tracking.SESSION_ID: mediaItem.extras[SESSION_ID],
      Tracking.SESSION_TITLE: mediaItem.title,
      Tracking.SESSION_LENGTH: mediaItem.extras[LENGTH],
      Tracking.SESSION_VOICE: mediaItem.artist
    }));
  }

  void _onBgMusicPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChooseBackgroundSoundDialog(
          handler: _handler, stream: _bloc.bgSoundsListController.stream),
    );
    // slight delay in case the cache returns before the sheet opens
    Future.delayed(Duration(milliseconds: 50))
        .then((value) => _bloc.fetchBackgroundSounds());
  }
}
