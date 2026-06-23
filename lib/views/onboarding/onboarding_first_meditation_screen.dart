import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/onboarding/onboarding_meditation_experiment.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';

enum _Phase { intro, loading, playing, done }

/// Final onboarding step in the meditation arm of
/// [OnboardingMeditationExperiment]. Plays a short guided meditation INLINE
/// (no navigation to the full player or end screen) so the user never leaves
/// onboarding, then rewards completion with a small streak-up animation before
/// continuing to home via [onNext]. Audio runs in the native service, so
/// completion analytics and the streak/stats bump happen regardless of UI.
class OnboardingFirstMeditationScreen extends ConsumerStatefulWidget {
  const OnboardingFirstMeditationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<OnboardingFirstMeditationScreen> createState() =>
      _OnboardingFirstMeditationScreenState();
}

class _OnboardingFirstMeditationScreenState
    extends ConsumerState<OnboardingFirstMeditationScreen> {
  _Phase _phase = _Phase.intro;
  int _priorStreak = 0;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    // Streak before this session, to animate from on completion (0 for a
    // brand-new user => "Day 1").
    _priorStreak = ref.read(statsProvider).value?.streakCurrent ?? 0;
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingFirstMeditationShown,
        parameters: {
          AnalyticsEventConstants.paramExperimentName:
              OnboardingMeditationExperiment.experimentName,
          AnalyticsEventConstants.paramVariantId:
              OnboardingMeditationExperiment.variantMeditation,
        },
      ),
    );
  }

  Future<void> _begin() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingFirstMeditationBeginTap,
      ),
    );
    setState(() => _phase = _Phase.loading);
    try {
      final track = await ref.read(
        tracksProvider(trackId: OnboardingMeditationExperiment.trackId).future,
      );
      final selection = TrackVariantSelector.resolve(
        track,
        guideName: OnboardingMeditationExperiment.guideName,
        durationMs: OnboardingMeditationExperiment.targetDurationMs,
      );
      final request =
          PlaybackRequest.fromTrack(track, selection.voice, selection.file);
      await ref.read(playerProvider.notifier).play(request);
      if (!mounted) return;
      setState(() => _phase = _Phase.playing);
    } catch (e, st) {
      // Never trap the user in onboarding if playback fails — log and continue.
      AppLogger.e('ONBOARDING', 'Failed to start first meditation', e, st);
      widget.onNext?.call();
    }
  }

  void _skip() {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingFirstMeditationSkipTap,
      ),
    );
    if (_phase == _Phase.playing || _phase == _Phase.loading) {
      ref.read(playerProvider.notifier).stop();
    }
    widget.onNext?.call();
  }

  // Toggles the native audio service (handles Android/iOS internally). The
  // intro track has no background sound layer, so no bg-sound sync is needed.
  void _togglePlayPause() => ref.read(playerProvider.notifier).playPause();

  @override
  Widget build(BuildContext context) {
    // Flip to the streak reveal the moment the inline session completes.
    ref.listen(audioStateProvider.select((s) => s.isCompleted),
        (prev, isCompleted) {
      if (isCompleted &&
          !_completionHandled &&
          (_phase == _Phase.playing || _phase == _Phase.loading)) {
        _completionHandled = true;
        setState(() => _phase = _Phase.done);
      }
    });

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (_phase) {
            _Phase.intro => _buildIntro(context, l10n),
            _Phase.loading => _buildPlaying(context, l10n, loading: true),
            _Phase.playing => _buildPlaying(context, l10n, loading: false),
            _Phase.done => _buildDone(context, l10n),
          },
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            Text(
              l10n.onboardingFirstMeditationTitle,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            // Prominent, reassuring duration cue — short commitment lowers the
            // barrier to actually pressing play.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: onSurface.withOpacityValue(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule,
                      size: 16, color: onSurface.withOpacityValue(0.85)),
                  const SizedBox(width: 6),
                  Text(
                    l10n.onboardingFirstMeditationDuration,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onSurface.withOpacityValue(0.85),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.onboardingFirstMeditationSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                    color: onSurface.withOpacityValue(0.9),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _begin,
                child: Text(
                  l10n.onboardingFirstMeditationBegin,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skip,
              child: Text(l10n.onboardingFirstMeditationSkip),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaying(BuildContext context, AppLocalizations l10n,
      {required bool loading}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final audio = ref.watch(audioStateProvider);
    final duration = audio.duration;
    final position = audio.position;
    final progress = (!loading && duration > 0)
        ? (position / duration).clamp(0.0, 1.0)
        : null;
    final busy = loading || audio.isBuffering;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.onboardingFirstMeditationTitle,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: onSurface.withOpacityValue(0.12),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loading
                  ? l10n.loading
                  : '${_fmt(position)}  /  ${_fmt(duration)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onSurface.withOpacityValue(0.7),
                  ),
            ),
          ],
        ),
        Column(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: busy ? null : _togglePlayPause,
                child: busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        audio.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skip,
              child: Text(l10n.onboardingFirstMeditationSkip),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final currentStreak =
        ref.watch(statsProvider).value?.streakCurrent ?? (_priorStreak + 1);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox.shrink(),
        Column(
          children: [
            Text(
              l10n.onboardingFirstMeditationDone,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Streak counts up from the pre-session value: the reward moment
            // for finishing a first meditation.
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: _priorStreak.toDouble(),
                end: currentStreak.toDouble(),
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '🔥 ${value.round()}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.dayStreak,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onSurface.withOpacityValue(0.9),
                  ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onNext?.call(),
            child: Text(
              l10n.onboardingFirstMeditationContinue,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}
