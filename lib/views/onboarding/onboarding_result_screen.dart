import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/onboarding/onboarding_meditation_experiment.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';

/// The three possible outcome states for the onboarding result screen.
enum OnboardingResultState {
  /// Never meditated OR wants to learn properly.
  stateA,

  /// Some experience + habit or stress/sleep goal.
  stateB,

  /// Regular practice.
  stateC,
}

extension OnboardingResultStateLabel on OnboardingResultState {
  String get analyticsLabel {
    switch (this) {
      case OnboardingResultState.stateA:
        return 'state_a';
      case OnboardingResultState.stateB:
        return 'state_b';
      case OnboardingResultState.stateC:
        return 'state_c';
    }
  }
}

/// Derives the result state from the experience answer.
///
/// The onboarding flow asks a single question — "Have you meditated before?".
/// The earlier "intent" question was removed because its answer carried almost
/// no predictive signal beyond the experience answer and added a screen of
/// friction; experience alone maps cleanly onto the three result states.
///
/// [experienceIndex] — answer to "Have you meditated before?"
///   0 = Never tried it          → State A (learn from scratch)
///   1 = A little, here and there → State B (ease back in)
///   2 = I have a regular practice → State C (keep the practice going)
OnboardingResultState deriveOnboardingState({
  required int experienceIndex,
}) {
  switch (experienceIndex) {
    case 2:
      return OnboardingResultState.stateC;
    case 1:
      return OnboardingResultState.stateB;
    case 0:
    default:
      return OnboardingResultState.stateA;
  }
}

/// The onboarding payoff screen. When [showMeditation] is true (the eligible
/// arm of [OnboardingMeditationExperiment]) it also hosts a short guided
/// meditation INLINE — play it right here, then a streak-up reveal — so there's
/// a single screen rather than a redundant "Get started" page followed by a
/// separate meditation. "Get started" is the one app-entry, after the session.
class OnboardingResultScreen extends ConsumerStatefulWidget {
  const OnboardingResultScreen({
    super.key,
    required this.state,
    required this.onGetStarted,
    this.showMeditation = false,
  });

  final OnboardingResultState state;
  final VoidCallback onGetStarted;
  final bool showMeditation;

  @override
  ConsumerState<OnboardingResultScreen> createState() =>
      _OnboardingResultScreenState();
}

class _OnboardingResultScreenState
    extends ConsumerState<OnboardingResultScreen> {
  bool _started = false;
  bool _loading = false;
  bool _done = false;
  bool _completionHandled = false;
  int _priorStreak = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showMeditation) {
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
  }

  Future<void> _begin() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingFirstMeditationBeginTap,
      ),
    );
    setState(() {
      _started = true;
      _loading = true;
    });
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
      setState(() => _loading = false);
    } catch (e, st) {
      AppLogger.e('ONBOARDING', 'Failed to start first meditation', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePlayPause() => ref.read(playerProvider.notifier).playPause();

  void _handleGetStarted() {
    // Leaving before finishing the inline meditation counts as a skip; stop the
    // audio so it doesn't keep playing into the app.
    if (widget.showMeditation && _started && !_done) {
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
          name: AnalyticsEventConstants.onboardingFirstMeditationSkipTap,
        ),
      );
      ref.read(playerProvider.notifier).stop();
    } else if (widget.showMeditation && !_started) {
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
          name: AnalyticsEventConstants.onboardingFirstMeditationSkipTap,
        ),
      );
    }
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    // Flip to the streak reveal the moment the inline session completes.
    ref.listen(audioStateProvider.select((s) => s.isCompleted),
        (prev, isCompleted) {
      if (widget.showMeditation &&
          isCompleted &&
          _started &&
          !_completionHandled) {
        _completionHandled = true;
        setState(() => _done = true);
      }
    });

    // In the meditation arm the heading is a hook that sells the payoff (a
    // moment of calm) to draw them into pressing play, rather than the generic
    // personalised payoff line used on the control screen.
    final heading = widget.showMeditation
        ? l10n.onboardingFirstMeditationHook
        : switch (widget.state) {
            OnboardingResultState.stateA => l10n.onboardingResultLearnHeading,
            OnboardingResultState.stateB => l10n.onboardingResultEaseInHeading,
            OnboardingResultState.stateC =>
              l10n.onboardingResultPracticeHeading,
          };

    final body = switch (widget.state) {
      OnboardingResultState.stateA => l10n.onboardingResultLearnBody,
      OnboardingResultState.stateB => l10n.onboardingResultEaseInBody,
      OnboardingResultState.stateC => l10n.onboardingResultPracticeBody,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        padding24,
        padding16,
        padding24,
        padding24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          // When the meditation card is shown the screen leads with action, not
          // reading, so the longer personalised body is dropped — the card's
          // own one-liner carries the reassurance.
          if (!widget.showMeditation) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
                height: 1.5,
              ),
            ),
          ],
          if (widget.showMeditation) ...[
            const SizedBox(height: 24),
            _buildMeditation(context, l10n),
          ],
          const SizedBox(height: 24),
          // While the session is the focus (meditation shown, not yet finished)
          // the play button is the hero, so "Get started" steps back to a quiet
          // skip link. It returns as the prominent CTA once the session is done
          // (or for the control arm, where there's no session to compete with).
          if (!widget.showMeditation || _done)
            _GetStartedButton(
              label: l10n.onboardingResultCta,
              onPressed: _handleGetStarted,
            )
          else
            Center(
              child: TextButton(
                onPressed: _handleGetStarted,
                child: Text(
                  _started
                      ? l10n.onboardingFirstMeditationSkipShort
                      : l10n.onboardingFirstMeditationSkip,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurface.withOpacityValue(0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeditation(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: onSurface.withOpacityValue(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _done
          ? _buildStreak(context, l10n)
          : _buildPlayer(context, l10n),
    );
  }

  Widget _buildPlayer(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final audio = ref.watch(audioStateProvider);
    final busy = _loading || audio.isBuffering;
    final duration = audio.duration;
    final position = audio.position;
    final progress = (_started && !busy && duration > 0)
        ? (position / duration).clamp(0.0, 1.0)
        : null;
    final isPlaying = _started && audio.isPlaying;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule,
                size: 15, color: onSurface.withOpacityValue(0.7)),
            const SizedBox(width: 5),
            Text(
              l10n.onboardingFirstMeditationDuration,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface.withOpacityValue(0.7),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.onboardingFirstMeditationSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onSurface.withOpacityValue(0.85),
                height: 1.4,
              ),
          textAlign: TextAlign.center,
        ),
        if (_started) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: onSurface.withOpacityValue(0.12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            busy ? l10n.loading : '${_fmt(position)}  /  ${_fmt(duration)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onSurface.withOpacityValue(0.6),
                ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: 64,
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: busy ? null : (_started ? _togglePlayPause : _begin),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreak(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final currentStreak =
        ref.watch(statsProvider).value?.streakCurrent ?? (_priorStreak + 1);
    return Column(
      children: [
        Text(
          l10n.onboardingFirstMeditationDone,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
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
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.dayStreak,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onSurface.withOpacityValue(0.9),
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

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.04,
  );

  bool _dispatched = false;

  @override
  void dispose() {
    _breathe.dispose();
    _press.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _press.forward();
  void _handleTapCancel() => _press.reverse();
  void _handleTapUp(_) => _press.reverse();

  void _handleTap() {
    if (_dispatched) return;
    _dispatched = true;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? ColorConstants.onyx : ColorConstants.lightOnSurface;
    return AnimatedBuilder(
      animation: Listenable.merge([_breathe, _press]),
      builder: (context, _) {
        final scale = 1.0 - _press.value;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            onTap: _handleTap,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(
                        -1.4 + (_breathe.value * 2.8),
                        -1.0,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 0.4,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.14),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
