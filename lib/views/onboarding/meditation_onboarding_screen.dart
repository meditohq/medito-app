import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

enum ExperienceLevel { never, some, regular }

enum MeditationIntent { learn, habit, manage }

enum OnboardingResultState { a, b, c }

class MeditationOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const MeditationOnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<MeditationOnboardingScreen> createState() =>
      _MeditationOnboardingScreenState();
}

class _MeditationOnboardingScreenState
    extends ConsumerState<MeditationOnboardingScreen> {
  final _analytics = FirebaseAnalyticsService();
  final _pageController = PageController();
  ExperienceLevel? _experience;
  MeditationIntent? _intent;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'meditation_onboarding_started');
  }

  OnboardingResultState _computeResultState() {
    // State A — never meditated OR wants to learn properly
    if (_experience == ExperienceLevel.never ||
        _intent == MeditationIntent.learn) {
      return OnboardingResultState.a;
    }
    // State C — regular practice
    if (_experience == ExperienceLevel.regular) {
      return OnboardingResultState.c;
    }
    // State B — some experience + habit or stress/sleep goal
    return OnboardingResultState.b;
  }

  void _onExperienceSelected(ExperienceLevel level) {
    setState(() => _experience = level);
    _analytics.logEvent(
      name: 'meditation_onboarding_answer',
      parameters: {
        'question': 'experience',
        'answer': level.name,
      },
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onIntentSelected(MeditationIntent intent) {
    setState(() => _intent = intent);
    _analytics.logEvent(
      name: 'meditation_onboarding_answer',
      parameters: {
        'question': 'intent',
        'answer': intent.name,
      },
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onGetStarted() {
    final resultState = _computeResultState();
    _analytics.logEvent(
      name: 'meditation_onboarding_completed',
      parameters: {'result_state': resultState.name},
    );
    // Suppress the explainer strip
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(SharedPreferenceConstants.hasSeenYourPathExplainer, true);
    widget.onComplete();
  }

  @override
  void dispose() {
    // If abandoned before completion
    if (_currentPage < 2) {
      _analytics.logEvent(
        name: 'meditation_onboarding_abandoned',
        parameters: {'last_page': _currentPage.toString()},
      );
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _currentPage = index),
          children: [
            _ExperienceScreen(
              onSelected: _onExperienceSelected,
              selected: _experience,
            ),
            _IntentScreen(
              onSelected: _onIntentSelected,
              selected: _intent,
            ),
            _ResultScreen(
              resultState: _computeResultState(),
              onGetStarted: _onGetStarted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperienceScreen extends StatelessWidget {
  final ValueChanged<ExperienceLevel> onSelected;
  final ExperienceLevel? selected;

  const _ExperienceScreen({required this.onSelected, this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            l10n.onboardingExperienceQuestion,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: sourceSerif,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingExperienceSubtext,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: teachers,
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),
          _OptionButton(
            text: l10n.onboardingExperienceNever,
            isSelected: selected == ExperienceLevel.never,
            onTap: () => onSelected(ExperienceLevel.never),
          ),
          const SizedBox(height: 12),
          _OptionButton(
            text: l10n.onboardingExperienceSome,
            isSelected: selected == ExperienceLevel.some,
            onTap: () => onSelected(ExperienceLevel.some),
          ),
          const SizedBox(height: 12),
          _OptionButton(
            text: l10n.onboardingExperienceRegular,
            isSelected: selected == ExperienceLevel.regular,
            onTap: () => onSelected(ExperienceLevel.regular),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _IntentScreen extends StatelessWidget {
  final ValueChanged<MeditationIntent> onSelected;
  final MeditationIntent? selected;

  const _IntentScreen({required this.onSelected, this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            l10n.onboardingIntentQuestion,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: sourceSerif,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingIntentSubtext,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: teachers,
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),
          _OptionButton(
            text: l10n.onboardingIntentLearn,
            isSelected: selected == MeditationIntent.learn,
            onTap: () => onSelected(MeditationIntent.learn),
          ),
          const SizedBox(height: 12),
          _OptionButton(
            text: l10n.onboardingIntentHabit,
            isSelected: selected == MeditationIntent.habit,
            onTap: () => onSelected(MeditationIntent.habit),
          ),
          const SizedBox(height: 12),
          _OptionButton(
            text: l10n.onboardingIntentManage,
            isSelected: selected == MeditationIntent.manage,
            onTap: () => onSelected(MeditationIntent.manage),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorConstants.lightBlue.withValues(alpha: 0.15)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? ColorConstants.lightBlue
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontFamily: teachers,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? ColorConstants.lightBlue
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  final OnboardingResultState resultState;
  final VoidCallback onGetStarted;

  const _ResultScreen({
    required this.resultState,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final heading = switch (resultState) {
      OnboardingResultState.a => l10n.onboardingResultHeadingA,
      OnboardingResultState.b => l10n.onboardingResultHeadingB,
      OnboardingResultState.c => l10n.onboardingResultHeadingC,
    };

    final body = switch (resultState) {
      OnboardingResultState.a => l10n.onboardingResultBodyA,
      OnboardingResultState.b => l10n.onboardingResultBodyB,
      OnboardingResultState.c => l10n.onboardingResultBodyC,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          Text(
            heading,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: sourceSerif,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: teachers,
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Your Path card preview (States A & B show it primary, C shows it secondary)
          if (resultState != OnboardingResultState.c)
            _PreviewCard(
              label: l10n.yourPath,
              title: l10n.onboardingResultSessionTitle,
              subtitle: l10n.onboardingResultSessionSub,
              hint: l10n.onboardingResultSwipeHint,
              isPrimary: true,
            ),
          if (resultState == OnboardingResultState.c)
            _PreviewCard(
              label: l10n.yourDaily,
              title: l10n.yourDailyDescription,
              subtitle: null,
              hint: null,
              isPrimary: true,
            ),
          // State B shows Your Daily as secondary
          if (resultState == OnboardingResultState.b) ...[
            const SizedBox(height: 16),
            _PreviewCard(
              label: l10n.yourDaily,
              title: l10n.yourDailyDescription,
              subtitle: null,
              hint: null,
              isPrimary: false,
            ),
          ],
          // State C shows Your Path note
          if (resultState == OnboardingResultState.c) ...[
            const SizedBox(height: 16),
            Text(
              l10n.yourPathSecondaryNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: teachers,
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onGetStarted,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n.getStarted,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final String? hint;
  final bool isPrimary;

  const _PreviewCard({
    required this.label,
    required this.title,
    this.subtitle,
    this.hint,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(padding16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? ColorConstants.lightBlue.withValues(alpha: 0.4)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          width: isPrimary ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: teachers,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: ColorConstants.lightBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: sourceSerif,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: teachers,
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: teachers,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
