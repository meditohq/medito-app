import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/views/player/widgets/artist_title_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/bottom_action_widget.dart';
import 'package:Medito/views/player/widgets/duration_indicator_widget.dart';
import 'package:Medito/views/player/widgets/overlay_cover_image_widget.dart';
import 'package:Medito/views/player/widgets/player_buttons/player_buttons_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/strings/route_constants.dart';
import '../../constants/strings/string_constants.dart';
import '../../providers/background_sounds/background_sounds_notifier.dart';
import '../../widgets/errors/medito_error_widget.dart';
import '../../widgets/headers/medito_app_bar_small.dart';

class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({
    super.key,
  });

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  bool _endScreenOpened = false;

  @override
  Widget build(BuildContext context) {
    var playbackState = ref.watch(audioStateProvider);

    if (playbackState.isCompleted && playbackState.position > 5000) {
      _resetState();
      _openEndScreen();
    }

    var currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        onTap: () => router.pop(),
        message: StringConstants.unableToLoadAudio,
      );
    }
    var file = currentlyPlayingTrack.audio.first.files.first;

    var size = MediaQuery.of(context).size.width;
    var spacerHeight48 = size <= 380.0 ? 10.0 : 56.0;
    var spacerHeight20 = size <= 380.0 ? 0.0 : 20.0;
    var spacerHeight24 = size <= 380.0 ? 0.0 : 24.0;

    return PopScope(
      canPop: false,
      onPopInvoked: _handleClose,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: MeditoAppBarSmall(
          hasCloseButton: true,
          closePressed: () => {_handleClose(true)},
          isTransparent: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: spacerHeight20),
                OverlayCoverImageWidget(imageUrl: playbackState.track.imageUrl),
                SizedBox(height: spacerHeight48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ArtistTitleWidget(
                    trackTitle: playbackState.track.title,
                    artistName: playbackState.track.artist,
                    artistUrlPath: playbackState.track.artistUrl,
                    isPlayerScreen: true,
                  ),
                ),
                DurationIndicatorWidget(
                  totalDuration: playbackState.duration,
                  currentPosition: playbackState.position,
                  onSeekEnd: (value) {
                    ref.read(playerProvider.notifier).seekToPosition(value);
                  },
                ),
                SizedBox(height: spacerHeight24),
                Transform.translate(
                  offset: Offset(0, -10),
                  child: PlayerButtonsWidget(
                    isPlaying: playbackState.isPlaying,
                    onPlayPause: () =>
                        ref.read(playerProvider.notifier).playPause(),
                    onSkip10SecondsBackward: () => ref
                        .read(playerProvider.notifier)
                        .skip10SecondsBackward(),
                    onSkip10SecondsForward: () => ref
                        .read(playerProvider.notifier)
                        .skip10SecondsForward(),
                  ),
                ),
                SizedBox(height: spacerHeight24),
                BottomActionWidget(
                  trackModel: currentlyPlayingTrack,
                  file: file,
                  onSpeedChanged: (speed) =>
                      ref.read(playerProvider.notifier).setSpeed(speed),
                  isBackgroundSoundSelected: _isBackgroundSoundSelected(),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isBackgroundSoundSelected() {
    var bgSoundNotifier = ref.read(backgroundSoundsNotifierProvider);

    return bgSoundNotifier.selectedBgSound != null &&
        bgSoundNotifier.selectedBgSound?.title != StringConstants.none;
  }

  void _handleClose(bool _) {
    _resetState();
    ref
        .read(playerProvider.notifier)
        .cancelBackgroundThreadForAudioCompleteEvent();
    router.pop();
  }

  void _resetState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).stop();
      ref.read(audioStateProvider.notifier).resetState();
    });
  }

  void _openEndScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_endScreenOpened) {
        var currentlyPlayingTrack = ref.read(playerProvider);
        var endScreen = currentlyPlayingTrack?.endScreen;
        if (endScreen != null) {
          context.pushReplacement(
            RouteConstants.endScreenPath,
            extra: endScreen,
          );
        }
        _endScreenOpened = true;
      }
    });
  }
}
