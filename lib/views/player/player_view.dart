// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/src/audio_pigeon.g.dart' as pigeon;
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
  // Snapshot of stats taken when the player opens, before the session can
  // affect them. EndScreenView uses this as the "before" value so its
  // AnimatedSwitcher actually animates from old streak -> new streak.
  LocalAllStats? _statsAtSessionStart;

  @override
  void initState() {
    super.initState();
    _statsAtSessionStart = ref.read(statsProvider).value;
    _logScreenView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCurrentTrackImage();
  }

  void _precacheCurrentTrackImage() {
    final currentlyPlayingTrack = ref.read(playerProvider);
    if (currentlyPlayingTrack != null) {
      _precacheImage(currentlyPlayingTrack.coverUrl);
    }
  }

  void _precacheImage(String imageUrl) {
    if (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasScheme == true) {
      if (!HTTPConstants.isDeadDomain(imageUrl)) {
        try {
          final networkImage = NetworkImage(imageUrl);
          unawaited(
            precacheImage(networkImage, context).catchError((error) {
              AppLogger.d('PlayerView',
                  'Failed to precache image: \$imageUrl, error: \$error');
            }),
          );
        } catch (e) {
          AppLogger.d('PlayerView',
              'Failed to create or precache image: \$imageUrl, error: \$e');
        }
      }
    }
  }

  Future<void> _logScreenView() async {
    final currentlyPlayingTrack = ref.read(playerProvider);
    final parameters = currentlyPlayingTrack != null
        ? {'trackid': currentlyPlayingTrack.trackId}
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
    } else {
      // Stop background sound if track doesn't allow it
      ref.read(backgroundSoundsNotifierProvider.notifier).stopBackgroundSound();
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
    final isCompleted =
        ref.watch(audioStateProvider.select((s) => s.isCompleted));
    if (isCompleted) {
      final position = ref.read(audioStateProvider).position;
      if (position > 5000) {
        _openEndScreen();
      }
    }

    final currentlyPlayingTrack = ref.watch(playerProvider);

    ref.listen(playerProvider.select((p) => p?.coverUrl), (_, next) {
      if (next != null) {
        _precacheImage(next);
      }
    });

    // Listen for track changes and handle background sounds
    ref.listen(playerProvider.select((p) => p?.hasBackgroundSound),
        (previous, next) {
      if (next == false) {
        // Stop background sound if track doesn't allow it
        ref
            .read(backgroundSoundsNotifierProvider.notifier)
            .stopBackgroundSound();
      } else if (next == true) {
        // Start background sound if track allows it
        ref
            .read(backgroundSoundsNotifierProvider.notifier)
            .playBackgroundSoundFromPref();
      }
    });

    if (currentlyPlayingTrack == null) {
      return MeditoErrorWidget(
        error: const UnknownError(),
        onTap: () => Navigator.pop(context),
      );
    }

    final track = ref.watch(audioStateProvider.select((s) => s.track));
    final isPlaying = ref.watch(audioStateProvider.select((s) => s.isPlaying));
    final imageUrl = track.imageUrl;

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
                RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty &&
                          !HTTPConstants.isDeadDomain(imageUrl))
                        // ImageFiltered (not BackdropFilter) — blurs only the
                        // cover image itself, never the screen behind. Using
                        // BackdropFilter here leaks the underlying route
                        // during pop animations, blurring the previous screen
                        // for a frame.
                        ImageFiltered(
                          imageFilter:
                              ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: _FadingNetworkImage(
                            imageUrl: imageUrl,
                          ),
                        ),
                      Container(
                        color: ColorConstants.black.withOpacityValue(0.3),
                      ),
                    ],
                  ),
                ),
                RepaintBoundary(
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32.0),
                              child: orientation == Orientation.portrait
                                  ? _PortraitPlayerLayout(
                                      track: track,
                                      isPlaying: isPlaying,
                                      onPlayPause: onPlayPausePressed,
                                    )
                                  : _LandscapePlayerLayout(
                                      track: track,
                                      isPlaying: isPlaying,
                                      onPlayPause: onPlayPausePressed,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child:
                              ReportButtonWidget(request: currentlyPlayingTrack),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: PlayerActionBar(
          request: currentlyPlayingTrack,
          isBackgroundSoundSelected: _isBackgroundSoundSelected(),
          onSpeedChanged: (speed) =>
              ref.read(playerProvider.notifier).setSpeed(speed),
          onClosePressed: () => _handleClose(),
        ),
      ),
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
    final bgSoundNotifier = ref.watch(backgroundSoundsNotifierProvider);
    final isPlaying = ref.watch(audioStateProvider.select((s) => s.isPlaying));

    return isPlaying &&
        bgSoundNotifier.selectedBgSound != null &&
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
        _stopAudio();
        final currentlyPlayingTrack = ref.read(playerProvider);
        if (currentlyPlayingTrack == null) return;

        // handleStats (run from the platform on completion) has already
        // written the new completion to local stats and pushed it through
        // statsProvider via refreshFromLocal — so no refresh() is needed
        // here. We pass the pre-session snapshot so EndScreenView can
        // animate from the old streak to the current one.
        unawaited(ref.read(dndProvider.notifier).setDndMode(false));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EndScreenView(
              request: currentlyPlayingTrack,
              priorStats: _statsAtSessionStart,
            ),
          ),
        );

        _endScreenOpened = true;
      }
    });
  }
}

class _PortraitPlayerLayout extends ConsumerWidget {
  const _PortraitPlayerLayout({
    required this.track,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final pigeon.Track track;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArtistTitleWidget(
          trackTitle: track.title.isNotEmpty == true ? track.title : '',
          artistName: track.artist?.isNotEmpty == true ? track.artist : '',
          artistUrlPath: track.artistUrl,
          isPlayerScreen: true,
        ),
        const SizedBox(height: 32),
        DurationIndicatorWidget(
          onSeekEnd: (value) {
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        const SizedBox(height: 24),
        PlayerButtonsWidget(
          isPlaying: isPlaying,
          onPlayPause: onPlayPause,
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
}

class _LandscapePlayerLayout extends ConsumerWidget {
  const _LandscapePlayerLayout({
    required this.track,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final pigeon.Track track;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArtistTitleWidget(
          trackTitle: track.title.isNotEmpty == true ? track.title : '',
          artistName: track.artist?.isNotEmpty == true ? track.artist : '',
          artistUrlPath: track.artistUrl,
          isPlayerScreen: true,
        ),
        DurationIndicatorWidget(
          onSeekEnd: (value) {
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        PlayerButtonsWidget(
          isPlaying: isPlaying,
          onPlayPause: onPlayPause,
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
