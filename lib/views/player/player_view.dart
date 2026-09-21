// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/audio_session_tracker.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/providers/donation/end_screen_donation_experiment.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
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
  const PlayerView({super.key});

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  bool _endScreenOpened = false;
  bool _isClosing = false;
  // Set when play() throws (e.g. offline, native audio failed to start). The
  // caller no longer awaits play() before navigating — we own starting
  // playback here — so this is how a start failure surfaces to the user.
  bool _startFailed = false;
  final _analytics = FirebaseAnalyticsService();
  // Snapshot of stats taken when the player opens, before the session can
  // affect them. EndScreenView uses this as the "before" value so its
  // AnimatedSwitcher actually animates from old streak -> new streak.
  LocalAllStats? _statsAtSessionStart;

  // Holds the end-screen donation ask alive while the player is open so the
  // fetch happens NOW, while the network is known to be up. When a session
  // ends with the screen off, the end screen is pushed on the next resume and
  // Android often hasn't restored connectivity yet — ~3.7% of those asks failed
  // to load (Sep 2026, GA4). A successful prefetch is kept alive by the
  // provider itself; a failed one is dropped when this subscription closes so
  // the end screen retries fresh.
  ProviderSubscription<AsyncValue<DonationPageModel>>? _donationAskWarmup;
  // Same idea for the localized end_screen ladder, only for installs already
  // in the inline-pay arm (peek, never assign here — the card assigns).
  ProviderSubscription<AsyncValue<PaywallConfigModel>>? _endScreenConfigWarmup;

  @override
  void initState() {
    super.initState();
    _statsAtSessionStart = ref.read(statsProvider).value;
    _logScreenView();
    _donationAskWarmup = ref.listenManual(fetchDonationPageProvider, (_, _) {});
    try {
      if (EndScreenDonationExperiment.isInlineVariant(
        ref.read(sharedPreferencesProvider),
      )) {
        _endScreenConfigWarmup = ref.listenManual(
          endScreenPaywallConfigProvider,
          (_, _) {},
        );
        // Also applies Stripe's publishable key, which the inline pay button
        // needs before it can open a sheet (keepAlive provider: no handle).
        unawaited(
          ref
              .read(paymentConfigProvider.future)
              .then(
                (_) {},
                onError: (Object e) =>
                    AppLogger.w('PLAYER', 'Payment config warm-up failed: $e'),
              ),
        );
      }
    } catch (e) {
      AppLogger.w('PLAYER', 'End-screen config warm-up skipped: $e');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
      _initializePlayer();
    });
  }

  /// Starts playback for the request the caller prepared. Runs here (rather
  /// than at the call site, awaited before navigation) so the screen opens
  /// instantly and shows a loading state while the audio spins up. A failure
  /// flips [_startFailed] so build() can show a retryable error instead of a
  /// silent, stuck player.
  Future<void> _startPlayback() async {
    final request = ref.read(playerProvider);
    if (request == null) return;
    try {
      await ref.read(playerProvider.notifier).play(request);
    } catch (e, st) {
      AppLogger.e('PLAYER', 'Failed to start playback', e, st);
      if (mounted) setState(() => _startFailed = true);
    }
  }

  void _retryPlayback() {
    setState(() => _startFailed = false);
    _startPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCurrentTrackImage();
  }

  @override
  void dispose() {
    // Analytics: leaving the player (e.g. system back gesture) abandons a
    // paused session. No-op if it's still playing (continues in background) or
    // already completed/stopped.
    unawaited(AudioSessionTracker.instance.onPlayerClosed());
    _donationAskWarmup?.close();
    _endScreenConfigWarmup?.close();
    super.dispose();
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
              AppLogger.d(
                'PlayerView',
                'Failed to precache image: \$imageUrl, error: \$error',
              );
            }),
          );
        } catch (e) {
          AppLogger.d(
            'PlayerView',
            'Failed to create or precache image: \$imageUrl, error: \$e',
          );
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
      // Only auto-prompt once; after that the user can opt in via Settings.
      // Avoids re-asking every session when they've declined.
      await healthKitManager.maybeRequestAuthorization();
    }

    // Only enable DND if permission is already granted and toggle is on
    if (Platform.isAndroid) {
      final dndNotifier = ref.read(dndProvider.notifier);
      final hasAccess = await dndNotifier.hasAccess();
      if (hasAccess) {
        await dndNotifier.setDndMode(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = ref.watch(
      audioStateProvider.select((s) => s.isCompleted),
    );
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
    ref.listen(playerProvider.select((p) => p?.hasBackgroundSound), (
      previous,
      next,
    ) {
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

    if (_startFailed) {
      return MeditoErrorWidget(
        error: const UnknownError(),
        onTap: _retryPlayback,
      );
    }

    final isPlaying = ref.watch(audioStateProvider.select((s) => s.isPlaying));

    // Static metadata comes from the prepared request, which is populated the
    // instant the screen opens. Sourcing it from audioState instead would show
    // an empty title/cover for the ~1s until native reports back, then pop the
    // real content in — the "jumping" we're avoiding.
    final title = currentlyPlayingTrack.title;
    final artistName = currentlyPlayingTrack.guideName;
    final artistUrl = currentlyPlayingTrack.artist?.path;
    final imageUrl = currentlyPlayingTrack.coverUrl;

    // The transport (play/pause + progress) is genuinely loading until the
    // native player reports it's playing or knows the duration. Everything
    // else on screen is already final, so only the play button shows a spinner.
    // Buffering (initial spin-up OR a mid-session re-buffer on a slow network)
    // counts as loading too — the spinner in place of the play button is the
    // right signal there, so we don't gate it to the start.
    final audioState = ref.watch(audioStateProvider);
    final isAudioLoading =
        !audioState.isCompleted &&
        (audioState.isBuffering ||
            (!audioState.isPlaying &&
                audioState.duration == 0 &&
                audioState.position == 0));

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
                          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: _FadingNetworkImage(imageUrl: imageUrl),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32.0,
                              ),
                              child: orientation == Orientation.portrait
                                  ? _PortraitPlayerLayout(
                                      title: title,
                                      artistName: artistName,
                                      artistUrl: artistUrl,
                                      totalDurationMs:
                                          currentlyPlayingTrack.duration,
                                      isPlaying: isPlaying,
                                      isLoading: isAudioLoading,
                                      onPlayPause: onPlayPausePressed,
                                    )
                                  : _LandscapePlayerLayout(
                                      title: title,
                                      artistName: artistName,
                                      artistUrl: artistUrl,
                                      totalDurationMs:
                                          currentlyPlayingTrack.duration,
                                      isPlaying: isPlaying,
                                      isLoading: isAudioLoading,
                                      onPlayPause: onPlayPausePressed,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: ReportButtonWidget(
                            request: currentlyPlayingTrack,
                          ),
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
        bgSoundNotifier.selectedBgSound?.id != kNoneBackgroundSoundId;
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
    required this.title,
    required this.artistName,
    required this.artistUrl,
    required this.totalDurationMs,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
  });

  final String title;
  final String? artistName;
  final String? artistUrl;
  final int totalDurationMs;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArtistTitleWidget(
          trackTitle: title,
          artistName: artistName ?? '',
          artistUrlPath: artistUrl,
          isPlayerScreen: true,
        ),
        const SizedBox(height: 32),
        DurationIndicatorWidget(
          fallbackDurationMs: totalDurationMs,
          onSeekEnd: (value) {
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        const SizedBox(height: 24),
        PlayerButtonsWidget(
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPlayPause: onPlayPause,
          onSkip10SecondsBackward: () =>
              ref.read(playerProvider.notifier).skip10SecondsBackward(),
          onSkip10SecondsForward: () =>
              ref.read(playerProvider.notifier).skip10SecondsForward(),
          onRepeat: () {
            final newMode = ref
                .read(repeatStateProvider.notifier)
                .toggleRepeat();
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
    required this.title,
    required this.artistName,
    required this.artistUrl,
    required this.totalDurationMs,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
  });

  final String title;
  final String? artistName;
  final String? artistUrl;
  final int totalDurationMs;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArtistTitleWidget(
          trackTitle: title,
          artistName: artistName ?? '',
          artistUrlPath: artistUrl,
          isPlayerScreen: true,
        ),
        DurationIndicatorWidget(
          fallbackDurationMs: totalDurationMs,
          onSeekEnd: (value) {
            ref.read(playerProvider.notifier).seekToPosition(value);
          },
        ),
        PlayerButtonsWidget(
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPlayPause: onPlayPause,
          onSkip10SecondsBackward: () =>
              ref.read(playerProvider.notifier).skip10SecondsBackward(),
          onSkip10SecondsForward: () =>
              ref.read(playerProvider.notifier).skip10SecondsForward(),
          onRepeat: () {
            final newMode = ref
                .read(repeatStateProvider.notifier)
                .toggleRepeat();
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

  const _FadingNetworkImage({required this.imageUrl});

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
        Container(color: backgroundColor),

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
