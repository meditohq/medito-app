import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/onboarding/onboarding_experienced_meditation_experiment.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/views/onboarding/onboarding_donation_screen.dart';
import 'package:medito/views/onboarding/onboarding_question_screen.dart';
import 'package:medito/views/onboarding/onboarding_result_screen.dart';
import 'package:medito/views/onboarding/battery_optimization_screen.dart';
import 'package:medito/views/onboarding/tracking_permission_screen.dart';
import 'package:medito/widgets/onboarding/progress_indicator_widget.dart';

class OnboardingPagerScreen extends ConsumerStatefulWidget {
  const OnboardingPagerScreen({super.key});

  @override
  ConsumerState<OnboardingPagerScreen> createState() =>
      OnboardingPagerScreenState();
}

class OnboardingPagerScreenState extends ConsumerState<OnboardingPagerScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Answer from the question screen (set before advancing to result).
  int? _experienceIndex;

  bool _showBatteryScreen = false;

  // onboarding_experienced_meditation arm; null unless `regular_practice`.
  String? _experiencedMeditationVariant;

  // The 3-min first-meditation step. never_tried/a_little retain best on a
  // short first session (~63-68% at <=3min). experienceIndex: 0 = never_tried,
  // 1 = a_little, 2 = regular_practice — regulars used to skip it
  // unconditionally, now under test by
  // OnboardingExperiencedMeditationExperiment.
  bool get _showMeditationStep {
    if (_experienceIndex == 0 || _experienceIndex == 1) return true;
    if (_experienceIndex == 2) {
      return _experiencedMeditationVariant ==
          OnboardingExperiencedMeditationExperiment.variantOffered;
    }
    return false;
  }

  final List<String> _images = [
    AssetConstants.onboardingImage1,
    AssetConstants.onboardingImage2,
    AssetConstants.onboardingImage3,
  ];

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  void _onExperienceSelected(int index) {
    const answers = ['never_tried', 'a_little', 'regular_practice'];
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.onboardingExperienceAnswered,
        parameters: {AnalyticsEventConstants.paramAnswer: answers[index]},
      ),
    );
    // Set as a GA4 user property so every downstream event (incl. the
    // first-session A/B test) can be segmented by experience level in
    // BigQuery without a join back to the onboarding event.
    unawaited(
      analytics.setUserProperty(
        name: AnalyticsEventConstants.userPropExperienceLevel,
        value: answers[index],
      ),
    );
    // Enrol only `regular_practice`; anyone else would dilute the denominator.
    var experiencedVariant = _experiencedMeditationVariant;
    if (index == 2) {
      experiencedVariant =
          OnboardingExperiencedMeditationExperiment.resolveVariant(
            ref.read(sharedPreferencesProvider),
          );
      unawaited(
        analytics.logEvent(
          name: AnalyticsEventConstants.onboardingExperimentExposure,
          parameters: {
            AnalyticsEventConstants.paramExperimentName:
                OnboardingExperiencedMeditationExperiment.experimentName,
            AnalyticsEventConstants.paramVariantId: experiencedVariant,
          },
        ),
      );
    }

    setState(() {
      _experienceIndex = index;
      _experiencedMeditationVariant = experiencedVariant;
    });
    // Persist the answer so it outlives onboarding — used to segment the
    // first-session experience (and its A/B test) and later personalisation.
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setInt(SharedPreferenceConstants.onboardingExperienceLevel, index),
    );
    // Pin every new user onto the path — this is also how the legacy megapack
    // retires: it stays the no-pin fallback, so pre-change users keep their
    // place in it and no backfill is needed.
    final startingPackId = index == 2
        ? PackSequence.experiencedEntryPackId
        : PackSequence.beginnerEntryPackId;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(SharedPreferenceConstants.upNextPackId, startingPackId),
    );
    ref.invalidate(upNextPackIdProvider);
    // Experience is now the only question in the onboarding flow — the
    // follow-up "intent" question was removed because its answer added a
    // screen of friction with almost no predictive value beyond this one.
    // Fire the flow-completed event here.
    _logQuestionFlowCompleted();
    _nextPage();
  }

  void _logQuestionFlowCompleted() {
    final state = deriveOnboardingState(experienceIndex: _experienceIndex ?? 0);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.onboardingQuestionFlowCompleted,
            parameters: {
              AnalyticsEventConstants.paramResultState: state.analyticsLabel,
            },
          ),
    );
  }

  List<Widget> _buildPages(AppLocalizations l10n) {
    final resultState = deriveOnboardingState(
      experienceIndex: _experienceIndex ?? 0,
    );

    return [
      OnboardingQuestionScreen(
        headerImage: _images[0],
        question: l10n.onboardingExperienceQuestion,
        subtext: l10n.onboardingExperienceSubtext,
        options: [
          l10n.onboardingExperienceNever,
          l10n.onboardingExperienceALittle,
          l10n.onboardingExperienceRegular,
        ],
        onOptionSelected: _onExperienceSelected,
      ),
      OnboardingDonationScreen(headerImage: _images[1], onNext: _nextPage),
      NotificationsScreen(headerImage: _images[2], onNext: _nextPage),
      if (_showBatteryScreen)
        BatteryOptimizationScreen(headerImage: _images[2], onNext: _nextPage),
      if (Platform.isIOS)
        TrackingPermissionScreen(headerImage: _images[2], onNext: _nextPage),
      OnboardingResultScreen(
        headerImage: _images[2],
        state: resultState,
        onGetStarted: _onGetStarted,
        showMeditation: _showMeditationStep,
      ),
    ];
  }

  Future<void> _onGetStarted() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: AnalyticsEventConstants.onboardingCompleted),
    );
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(
            SharedPreferenceConstants.firstActionAfterOnboardingPending,
            true,
          ),
    );
    await _finishToHome();
  }

  Future<void> _finishToHome() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, a, b) => const BottomNavigationBarView(),
        transitionsBuilder: (_, animation, secondary, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          // Incoming home: gentle fade + small scale-up from 0.96.
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(eased);
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.onboardingQuestionFlowStarted,
          ),
    );
    shouldShowBatteryOptimizationScreen().then((show) {
      if (mounted) setState(() => _showBatteryScreen = show);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _buildPages(l10n);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) => pages[index],
              ),
            ),
            OnboardingProgressIndicator(
              currentIndex: _currentPage,
              totalSteps: pages.length,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
