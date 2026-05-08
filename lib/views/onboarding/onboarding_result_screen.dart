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

/// Derives the result state from the two question answers.
///
/// [experienceIndex] — answer to "Have you meditated before?"
///   0 = Never tried it
///   1 = A little, here and there
///   2 = I have a regular practice
///
/// [intentIndex] — answer to "What are you hoping to get from meditation?"
///   0 = Learn how to meditate properly
///   1 = Build a regular habit
///   2 = Manage stress, sleep, or emotions
OnboardingResultState deriveOnboardingState({
  required int experienceIndex,
  required int intentIndex,
}) {
  // State A: never tried OR wants to learn properly
  if (experienceIndex == 0 || intentIndex == 0) {
    return OnboardingResultState.stateA;
  }
  // State C: regular practice (regardless of intent)
  if (experienceIndex == 2) {
    return OnboardingResultState.stateC;
  }
  // State B: some experience + habit or stress/sleep goal
  return OnboardingResultState.stateB;
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
    return AnimatedBuilder(
      animation: Listenable.merge([_breathe, _press]),
      builder: (context, _) {
        final breathe = Curves.easeInOut.transform(_breathe.value);
        final scale = 1.0 + (breathe * 0.015) - _press.value;
        final glow = 0.35 + (breathe * 0.25);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            onTap: _handleTap,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorConstants.lightPurple,
                    ColorConstants.lightPrimary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ColorConstants.lightPurple.withValues(alpha: glow),
                    blurRadius: 28,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Align(
                        alignment: Alignment(
                          -1.0 + (_breathe.value * 2.0),
                          -1.0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.35,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Transform.translate(
                          offset: Offset(breathe * 3, 0),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
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
