import 'dart:ui';

import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/end_screen/end_screen_view.dart';
import 'package:medito/views/player/widgets/artist_title_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/player_action_bar.dart';
import 'package:medito/views/player/widgets/duration_indicator_widget.dart';
import 'package:medito/views/player/widgets/player_buttons/player_buttons_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _isClosing = false;

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
    }

    final currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        onTap: () => Navigator.pop(context),
        message: StringConstants.unableToLoadAudio,
      );
    }

    final file = currentlyPlayingTrack.audio.first.files.first;
    final imageUrl = playbackState.track.imageUrl;

    if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasScheme == true) {
      precacheImage(NetworkImage(imageUrl), context);
    }

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _resetState();
          _stopAudio();
        }
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  FadeInImage.assetNetwork(
                    key: ValueKey(imageUrl),
                    placeholder: AssetConstants.placeholder,
                    image: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(seconds: 2),
                  ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: ColorConstants.black.withOpacity(0.3),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: orientation == Orientation.portrait
                            ? _buildPortraitLayout(playbackState)
                            : _buildLandscapeLayout(playbackState),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: PlayerActionBar(
          trackModel: currentlyPlayingTrack,
          file: file,
          onClosePressed: () => _handleClose(),
          onSpeedChanged: (speed) =>
              ref.read(playerProvider.notifier).setSpeed(speed),
          isBackgroundSoundSelected: _isBackgroundSoundSelected(),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(PlaybackState playbackState) {
    return Column(
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
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        const SizedBox(height: 24),
        PlayerButtonsWidget(
          isPlaying: playbackState.isPlaying,
          onPlayPause: onPlayPausePressed,
          onSkip10SecondsBackward: () =>
              ref.read(playerProvider.notifier).skip10SecondsBackward(),
          onSkip10SecondsForward: () =>
              ref.read(playerProvider.notifier).skip10SecondsForward(),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(PlaybackState playbackState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArtistTitleWidget(
          trackTitle: playbackState.track.title,
          artistName: playbackState.track.artist,
          artistUrlPath: playbackState.track.artistUrl,
          isPlayerScreen: true,
        ),
        DurationIndicatorWidget(
          totalDuration: playbackState.duration,
          currentPosition: playbackState.position,
          onSeekEnd: (value) {
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        PlayerButtonsWidget(
          isPlaying: playbackState.isPlaying,
          onPlayPause: onPlayPausePressed,
          onSkip10SecondsBackward: () =>
              ref.read(playerProvider.notifier).skip10SecondsBackward(),
          onSkip10SecondsForward: () =>
              ref.read(playerProvider.notifier).skip10SecondsForward(),
        ),
      ],
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

  void _handleClose({bool shouldPop = true}) {
    if (_isClosing) {
      return;
    }
    _isClosing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetState();
      _stopAudio();
      _endScreenOpened = false;

      if (shouldPop && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _isClosing = false;
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
        if (currentlyPlayingTrack != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EndScreenView(
                trackModel: currentlyPlayingTrack,
              ),
            ),
          );

          _endScreenOpened = true;
        }
      }
    });
  }
}
