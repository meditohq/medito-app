import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/buttons/loading_button_widget.dart';

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
///   1 = Build a daily habit
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
          SizedBox(
            width: double.infinity,
            child: LoadingButtonWidget(
              onPressed: onGetStarted,
              btnText: l10n.onboardingResultCta,
            ),
          ),
        ],
      ),
    );
  }
}
