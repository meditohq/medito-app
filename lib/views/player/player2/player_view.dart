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
import 'package:Medito/components/components.dart';
import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/player/components/position_indicator_widget.dart';
import 'package:Medito/views/player/components/subtitle_text_widget.dart';
import 'package:Medito/views/player/player2/audio_complete_dialog.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../audioplayer/audio_inherited_widget.dart';
import '../../../tracking/tracking.dart';
import '../../../utils/bgvolume_utils.dart';

class PlayerWidget extends StatefulWidget {
  final normalPop;

  PlayerWidget({this.normalPop});

  @override
  _PlayerWidgetState createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  MeditoAudioHandler? _handler;
  late PlayerBloc _bloc;

  @override
  void dispose() {
    _handler?.stop();
    _bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startTimeout();
    _bloc = PlayerBloc();

    Future.delayed(Duration(milliseconds: 200)).then((value) async {
      var bgSound = await getBgSoundNameFromSharedPrefs();
      var volume = await retrieveSavedBgVolume();
      await _handler
          ?.customAction(SET_BG_SOUND_VOL, {SET_BG_SOUND_VOL: volume});
      return _handler?.customAction(SEND_BG_SOUND, {SEND_BG_SOUND: bgSound});
    });
  }

  void _startTimeout() {
    var timerMaxSeconds = 20;
    Timer.periodic(Duration(seconds: timerMaxSeconds), (timer) {
      if (_handler?.playbackState.value.processingState ==
              AudioProcessingState.loading &&
          mounted) {
        createSnackBar(StringConstants.TIMEOUT, context);
      }
      timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    _handler = AudioHandlerInheritedWidget.of(context).audioHandler;
    var mediaItem = _handler?.mediaItem.value;

    tryLoadingBgSoundsData();

    _handler?.customEvent.stream.listen((event) {
      if (mounted &&
          event[AUDIO_COMPLETE] is bool &&
          event[AUDIO_COMPLETE] == true) {
        _trackSessionEnd(_handler?.mediaItem.value);
        showGeneralDialog(
            transitionDuration: Duration(milliseconds: 400),
            context: context,
            barrierColor: MeditoColors.darkMoon,
            pageBuilder: (_, __, ___) {
              return AudioCompleteDialog(
                  bloc: _bloc, mediaItem: _handler?.mediaItem.value);
            });
      }
    });

    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: getNetworkImage(mediaItem!.artUri.toString()),
            fit: BoxFit.fill,
            colorFilter: ColorFilter.mode(
                MeditoColors.almostBlack.withOpacity(0.65), BlendMode.overlay),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CloseButtonComponent(
                onPressed: () => router.pop(),
                bgColor: MeditoColors.walterWhite,
                icColor: MeditoColors.almostBlack,
              ),
              Spacer(),
              _buildTitleRows(),
              Spacer(),
              _buildPlayerButtonRow(mediaItem),
              // A seek bar.
              PositionIndicatorWidget(
                  handler: _handler,
                  bgSoundsStream: _bloc.bgSoundsListController?.stream),
              Container(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void tryLoadingBgSoundsData() {
    try {
      var x = _handler;
      print(x);
      if (_hasBGSound() != null && _hasBGSound() == true) {
        getSavedBgSoundData();
      }
    } on Exception catch (e, s) {
      unawaited(
        Sentry.captureException(e,
            stackTrace: s,
            hint:
                'Failed trying to get save background  sounds data: extras[HAS_BG_SOUND]: ${_hasBGSound()}'),
      );
    }
  }

  bool? _hasBGSound() => _handler?.mediaItemHasBGSound();

  StreamBuilder<bool> _buildPlayPauseButtons(MediaItem? mediaItem) {
    return StreamBuilder<bool>(
      stream: _handler?.playbackState.map((state) => state.playing).distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        if (playing) {
          return _pauseButton();
        } else {
          return _playButton(mediaItem);
        }
      },
    );
  }

  StreamBuilder<MediaItem> _buildTitleRows() {
    return StreamBuilder<MediaItem>(
      stream: _handler?.mediaItem.cast(),
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          child: Column(
            children: [
              _getTitleRow(mediaItem),
              _getSubtitleWidget(mediaItem),
            ],
          ),
        );
      },
    );
  }

  Text _getTitleRow(MediaItem? mediaItem) {
    return Text(
      // mediaItem?.title ?? 'Loading...',
      'This is an example of a very long title and a session with an artist',
      textAlign: TextAlign.center,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
          fontFamily: ClashDisplay,
          color: MeditoColors.walterWhite,
          fontSize: 24,
          letterSpacing: 1),
    );
  }

  Padding _getSubtitleWidget(MediaItem? mediaItem) {
    var attr = mediaItem?.extras != null ? (mediaItem?.extras?['attr']) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SubtitleTextWidget(
          body: 'Giovanni Dienstmann https://www.google.com/'),
    );
  }

  Widget _playButton(MediaItem? mediaItem) => Semantics(
        label: 'Play button',
        child: IconButton(
          color: MeditoColors.walterWhite,
          icon: Icon(Icons.play_circle_fill),
          iconSize: 80,
          onPressed: () =>
              _playPressed(mediaItem?.extras?[HAS_BG_SOUND] ?? true),
        ),
      );

  Future<void> _playPressed(bool hasBgSound) async {
    await _handler?.play();
    if (hasBgSound) await getSavedBgSoundData();
  }

  Widget _pauseButton() => Semantics(
        label: 'Pause button',
        child: IconButton(
          icon: Icon(Icons.pause_circle_filled),
          iconSize: 80,
          color: MeditoColors.walterWhite,
          onPressed: _handler?.pause,
        ),
      );

  Future<void> getSavedBgSoundData() async {
    var file = await getBgSoundFileFromSharedPrefs();
    var name = await getBgSoundNameFromSharedPrefs();
    unawaited(_handler?.customAction(SEND_BG_SOUND, {SEND_BG_SOUND: name}));
    unawaited(_handler?.customAction(PLAY_BG_SOUND, {PLAY_BG_SOUND: file}));
  }

  void _onBackPressed() {
    GoRouter.of(context).pop();
  }

  void _trackSessionEnd(MediaItem? mediaItem) {
    if (mediaItem == null) return;
    unawaited(
      Tracking.postUsage(
        Tracking.AUDIO_COMPLETED,
        {
          Tracking.SESSION_ID: mediaItem.extras?[SESSION_ID].toString() ?? '',
          Tracking.SESSION_DURATION: mediaItem.extras?[LENGTH].toString() ?? '',
          Tracking.SESSION_GUIDE: mediaItem.artist ?? ''
        },
      ),
    );
  }

  Widget _buildPlayerButtonRow(MediaItem? mediaItem) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRewindButton(),
        SizedBox(width: 35),
        _buildPlayPauseButtons(mediaItem),
        SizedBox(width: 35),
        _buildForwardButton()
      ],
    );
  }

  InkWell _buildRewindButton() {
    return InkWell(
      onTap: () => _handler?.skipBackward10Secs(),
      child: SvgPicture.asset(
        AssetConstants.icReplay10,
      ),
    );
  }

  InkWell _buildForwardButton() {
    return InkWell(
      onTap: () => _handler?.skipForward30Secs(),
      child: SvgPicture.asset(
        AssetConstants.icForward30,
      ),
    );
  }

  Widget _buildImage(String? currentImage) {
    return Container(
        width: double.maxFinite,
        child: getNetworkImageWidget(currentImage ?? ''));
  }
}
