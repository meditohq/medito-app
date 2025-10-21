// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/end_screen/end_screen_view.dart';
import 'package:medito/views/player/widgets/artist_title_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/player_action_bar.dart';
import 'package:medito/views/player/widgets/duration_indicator_widget.dart';
import 'package:medito/views/player/widgets/player_buttons/player_buttons_widget.dart';
import 'package:medito/widgets/report_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_sounds/background_sounds_notifier.dart';
import '../../providers/player/repeat_state_provider.dart';
import '../../widgets/errors/medito_error_widget.dart';
import '../../utils/health_kit_manager.dart';

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
  final _analytics = FirebaseAnalyticsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
      _logScreenView();
    });
  }

  Future<void> _logScreenView() async {
    final currentlyPlayingTrack = ref.read(playerProvider);
    final parameters = currentlyPlayingTrack != null
        ? {'trackid': currentlyPlayingTrack.id}
        : null;

    await _analytics.logScreenView(
      screenName: 'PlayerView',
      parameters: parameters,
    );
  }

  Future<void> _initializePlayer() async {
    final currentlyPlayingTrack = ref.watch(playerProvider);
    if (currentlyPlayingTrack?.hasBackgroundSound ?? false) {
      ref
          .read(backgroundSoundsNotifierProvider.notifier)
          .playBackgroundSoundFromPref();
    }

    var healthKitManager = HealthKitManager();
    if (await healthKitManager.isHealthSyncPermitted() != true) {
      await healthKitManager.requestAuthorization();
    }

    // Only enable DND if permission is already granted and toggle is on
    if (Platform.isAndroid) {
      final dndNotifier = ref.read(dndProvider.notifier);
      final hasAccess = await dndNotifier.checkNotificationPolicyAccess();
      if (hasAccess) {
        await dndNotifier.setDndMode(true);
      }
    }
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
        error: const UnknownError(),
        onTap: () => Navigator.pop(context),
      );
    }

    final file = currentlyPlayingTrack.audio.first.files.first;
    final imageUrl = playbackState.track.imageUrl;

    if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasScheme == true) {
      try {
        precacheImage(NetworkImage(imageUrl), context).catchError((error) {
          // Silently handle precaching errors - they're not critical
          AppLogger.d('PlayerView',
              'Failed to precache image: $imageUrl, error: $error');
        });
      } catch (e) {
        // Silently handle any synchronous errors from precaching
        AppLogger.d(
            'PlayerView', 'Failed to precache image: $imageUrl, error: $e');
      }
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
                  _FadingNetworkImage(
                    imageUrl: imageUrl,
                  ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: ColorConstants.black.withOpacity(0.3),
                  ),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32.0),
                            child: orientation == Orientation.portrait
                                ? _buildPortraitLayout(playbackState)
                                : _buildLandscapeLayout(playbackState),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: ReportButtonWidget(track: currentlyPlayingTrack),
                      ),
                    ],
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
          isBackgroundSoundSelected: _isBackgroundSoundSelected(),
          onSpeedChanged: (speed) =>
              ref.read(playerProvider.notifier).setSpeed(speed),
          onClosePressed: () => _handleClose(),
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
          trackTitle: playbackState.track.title.isNotEmpty == true
              ? playbackState.track.title
              : '',
          artistName: playbackState.track.artist?.isNotEmpty == true
              ? playbackState.track.artist
              : '',
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
          onRepeat: () {
            final newMode =
                ref.read(repeatStateProvider.notifier).toggleRepeat();
            ref.read(playerProvider.notifier).setRepeatMode(newMode);
          },
          isPortrait: true,
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
          trackTitle: playbackState.track.title.isNotEmpty == true
              ? playbackState.track.title
              : '',
          artistName: playbackState.track.artist?.isNotEmpty == true
              ? playbackState.track.artist
              : '',
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
          onRepeat: () {
            final newMode =
                ref.read(repeatStateProvider.notifier).toggleRepeat();
            ref.read(playerProvider.notifier).setRepeatMode(newMode);
          },
          isPortrait: false,
        ),
      ],
    );
  }

  void onPlayPausePressed() {
    final isPlaying = ref.read(audioStateProvider).isPlaying;

    // Control primary track
    ref.read(playerProvider.notifier).playPause();

    // For iOS, we need to explicitly toggle background sound too
    // Android will handle it in the native implementation
    if (Platform.isIOS) {
      ref
          .read(backgroundSoundsNotifierProvider.notifier)
          .togglePlayPause(isPlaying);
    }
  }

  bool _isBackgroundSoundSelected() {
    final bgSoundNotifier = ref.read(backgroundSoundsNotifierProvider);

    return bgSoundNotifier.selectedBgSound != null &&
        bgSoundNotifier.selectedBgSound?.title !=
            AppLocalizations.of(context)!.none;
  }

  void _handleClose({bool shouldPop = true}) {
    if (_isClosing) {
      return;
    }
    _isClosing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _resetState();
      _stopAudio();

      await ref.read(dndProvider.notifier).setDndMode(false);
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
      if (!_endScreenOpened && mounted) {
        _resetState();
        final currentlyPlayingTrack = ref.read(playerProvider);
        if (currentlyPlayingTrack != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;

            ref.read(statsProvider.notifier).refresh();
            unawaited(ref.read(dndProvider.notifier).setDndMode(false));

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EndScreenView(
                  trackModel: currentlyPlayingTrack,
                ),
              ),
            );
          });

          _endScreenOpened = true;
        }
      }
    });
  }
}

class _FadingNetworkImage extends StatefulWidget {
  final String imageUrl;

  const _FadingNetworkImage({
    required this.imageUrl,
  });

  @override
  State<_FadingNetworkImage> createState() => _FadingNetworkImageState();
}

class _FadingNetworkImageState extends State<_FadingNetworkImage> {
  bool _imageLoaded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? ColorConstants.greyIsTheNewGrey
        : ColorConstants.lightBackground;

    return Stack(
      fit: StackFit.expand,
      children: [ 
        // Grey background while loading
        Container(
          color: backgroundColor,
        ),

        // Network image with fade-in effect
        AnimatedOpacity(
          opacity: _imageLoaded ? 1.0 : 0.0,
          duration: const Duration(seconds: 2),
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            cacheWidth: MediaQuery.of(context).size.width.toInt(),
            errorBuilder: (context, error, stackTrace) {
              return Container(color: backgroundColor);
            },
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame != null && !_imageLoaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _imageLoaded = true;
                    });
                  }
                });
              }
              return child;
            },
          ),
        ),
      ],
    );
  }
}
