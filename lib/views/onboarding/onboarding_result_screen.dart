import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';

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

class OnboardingResultScreen extends StatelessWidget {
  const OnboardingResultScreen({
    super.key,
    required this.state,
    required this.onGetStarted,
  });

  final OnboardingResultState state;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final heading = switch (state) {
      OnboardingResultState.stateA => l10n.onboardingResultLearnHeading,
      OnboardingResultState.stateB => l10n.onboardingResultEaseInHeading,
      OnboardingResultState.stateC => l10n.onboardingResultPracticeHeading,
    };

    final body = switch (state) {
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
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _GetStartedButton(
            label: l10n.onboardingResultCta,
            onPressed: onGetStarted,
          ),
        ],
      ),
    );
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
