import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
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

  // Answers from the question screens (set before advancing to result).
  int? _experienceIndex;
  int? _intentIndex;

  bool _showBatteryScreen = false;

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
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingExperienceAnswered,
        parameters: {
          AnalyticsEventConstants.paramAnswer: answers[index],
        },
      ),
    );
    setState(() => _experienceIndex = index);
    _nextPage();
  }

  void _onIntentSelected(int index) {
    const answers = ['learn_properly', 'build_habit', 'stress_sleep_emotions'];
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingIntentAnswered,
        parameters: {
          AnalyticsEventConstants.paramAnswer: answers[index],
        },
      ),
    );
    setState(() => _intentIndex = index);
    // Intent is now the final question in the onboarding flow — the previous
    // attribution question was removed because its conversion cost outweighed
    // the value of the data. Fire the flow-completed event here.
    _logQuestionFlowCompleted();
    _nextPage();
  }

  void _logQuestionFlowCompleted() {
    final state = deriveOnboardingState(
      experienceIndex: _experienceIndex ?? 0,
      intentIndex: _intentIndex ?? 0,
    );
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
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
      intentIndex: _intentIndex ?? 0,
    );

    return [
      OnboardingQuestionScreen(
        question: l10n.onboardingExperienceQuestion,
        subtext: l10n.onboardingExperienceSubtext,
        options: [
          l10n.onboardingExperienceNever,
          l10n.onboardingExperienceALittle,
          l10n.onboardingExperienceRegular,
        ],
        stepLabel: l10n.onboardingStep1of2,
        onOptionSelected: _onExperienceSelected,
      ),
      OnboardingQuestionScreen(
        question: l10n.onboardingIntentQuestion,
        subtext: l10n.onboardingIntentSubtext,
        options: [
          l10n.onboardingIntentLearn,
          l10n.onboardingIntentHabit,
          l10n.onboardingIntentStress,
        ],
        stepLabel: l10n.onboardingStep2of2,
        onOptionSelected: _onIntentSelected,
      ),
      OnboardingDonationScreen(onNext: _nextPage),
      NotificationsScreen(onNext: _nextPage, intentIndex: _intentIndex),
      if (_showBatteryScreen) BatteryOptimizationScreen(onNext: _nextPage),
      if (Platform.isIOS) TrackingPermissionScreen(onNext: _nextPage),
      OnboardingResultScreen(
        state: resultState,
        onGetStarted: _onGetStarted,
      ),
    ];
  }

  Future<void> _onGetStarted() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.onboardingCompleted,
      ),
    );
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(
            SharedPreferenceConstants.firstActionAfterOnboardingPending,
            true,
          ),
    );
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
      ref.read(analyticsServiceProvider).logEvent(
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
            Visibility(
              visible: MediaQuery.of(context).size.height > 500 &&
                  MediaQuery.of(context).orientation == Orientation.portrait,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    _images[_currentPage < _images.length
                        ? _currentPage
                        : _images.length - 1],
                    key: ValueKey<String>(_images[_currentPage < _images.length
                        ? _currentPage
                        : _images.length - 1]),
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
