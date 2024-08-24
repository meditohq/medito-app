import 'dart:ui';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/views/end_screen/end_screen_view.dart';
import 'package:Medito/views/player/widgets/artist_title_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/player_action_bar.dart';
import 'package:Medito/views/player/widgets/duration_indicator_widget.dart';
import 'package:Medito/views/player/widgets/player_buttons/player_buttons_widget.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/strings/string_constants.dart';
import '../../providers/background_sounds/background_sounds_notifier.dart';
import '../../widgets/errors/medito_error_widget.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentlyPlayingTrack = ref.watch(playerProvider);
      if (currentlyPlayingTrack?.hasBackgroundSound ?? false) {
        ref
            .read(backgroundSoundsNotifierProvider.notifier)
            .playBackgroundSoundFromPref();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(audioStateProvider);
    if (playbackState.isCompleted && playbackState.position > 5000) {
      _openEndScreen();
      _resetState();
    }

    final currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        onTap: () => Navigator.pop(context),
        message: StringConstants.unableToLoadAudio,
      );
    }

    final file = currentlyPlayingTrack.audio.first.files.first;

    return PopScope(
      canPop: false,
      onPopInvoked: _handleClose,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.network(
                playbackState.track.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              color: Colors.black.withOpacity(0.6),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ArtistTitleWidget(
                          trackTitle: playbackState.track.title,
                          artistName: playbackState.track.artist,
                          artistUrlPath: playbackState.track.artistUrl,
                          isPlayerScreen: true,
                        ),
                        const SizedBox(height: 32),
                        DurationIndicatorWidget(
                          totalDuration: playbackState.duration,
                          currentPosition: playbackState.position,
                          onSeekEnd: (value) {
                            ref
                                .read(playerProvider.notifier)
                                .seekToPosition(value);
                          },
                        ),
                        const SizedBox(height: 24),
                        PlayerButtonsWidget(
                          isPlaying: playbackState.isPlaying,
                          onPlayPause: onPlayPausePressed,
                          onSkip10SecondsBackward: () => ref
                              .read(playerProvider.notifier)
                              .skip10SecondsBackward(),
                          onSkip10SecondsForward: () => ref
                              .read(playerProvider.notifier)
                              .skip10SecondsForward(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: PlayerActionBar(
          trackModel: currentlyPlayingTrack,
          file: file,
          onClosePressed: () => _handleClose(true),
          onSpeedChanged: (speed) =>
              ref.read(playerProvider.notifier).setSpeed(speed),
          isBackgroundSoundSelected: _isBackgroundSoundSelected(),
        ),
      ),
    );
  }

  void onPlayPausePressed() {
    final isPlaying = ref.read(audioStateProvider).isPlaying;
    ref.read(playerProvider.notifier).playPause();
    ref
        .read(backgroundSoundsNotifierProvider.notifier)
        .togglePlayPause(isPlaying);
  }

  bool _isBackgroundSoundSelected() {
    final bgSoundNotifier = ref.read(backgroundSoundsNotifierProvider);

    return bgSoundNotifier.selectedBgSound != null &&
        bgSoundNotifier.selectedBgSound?.title != StringConstants.none;
  }

  bool _isClosing = false;

  void _handleClose(bool _) {
    if (_isClosing) {
      return;
    }
    _isClosing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.canPop(context)) {
        _resetState();
        _stopAudio();
        _endScreenOpened = false;

        Future.delayed(const Duration(milliseconds: 50), () {
          Navigator.pop(context);
          _isClosing = false;
        });
      } else {
        _isClosing = false;
      }
    });
  }

  void _stopAudio() {
    ref.read(playerProvider.notifier).stop();
    ref.read(backgroundSoundsNotifierProvider.notifier).stopBackgroundSound();
  }

  void _resetState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioStateProvider.notifier).resetState();
    });
  }

  void _openEndScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_endScreenOpened) {
        _resetState();
        final currentlyPlayingTrack = ref.read(playerProvider);
        if (currentlyPlayingTrack != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EndScreenView(trackModel: currentlyPlayingTrack),
            ),
          );

          _endScreenOpened = true;
        }
      }
    });
  }
}
