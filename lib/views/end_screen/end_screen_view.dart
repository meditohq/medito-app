import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

import 'widgets/donation_widget.dart';
import 'widgets/zen_mode_animation.dart';

class EndScreenView extends ConsumerStatefulWidget {
  final TrackModel trackModel;

  const EndScreenView({
    super.key,
    required this.trackModel,
  });

  @override
  ConsumerState<EndScreenView> createState() => _EndScreenViewState();
}

class _EndScreenViewState extends ConsumerState<EndScreenView>
    with TickerProviderStateMixin {
  final _animatedSwitcherKey = GlobalKey();
  final _analytics = FirebaseAnalyticsService();

  late AnimationController _statsAnimationController;
  late AnimationController _reminderAnimationController;
  late AnimationController _cardAnimationController;

  late Animation<Offset> _statsSlideAnimation;
  late Animation<double> _statsFadeAnimation;
  late Animation<Offset> _reminderSlideAnimation;
  late Animation<double> _reminderFadeAnimation;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _logScreenView();

    _statsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _reminderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _statsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _statsFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeOut,
    ));

    _reminderSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _reminderAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _reminderFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _reminderAnimationController,
      curve: Curves.easeOut,
    ));

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _statsAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _reminderAnimationController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _cardAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _statsAnimationController.dispose();
    _reminderAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'EndScreenView');
  }

  void _loadStats() async {
    // Load stats immediately
    await ref.read(statsProvider.notifier).refresh();

    if (!mounted) return;

    // Once stats are loaded, check for app review request
    final reviewService = ref.read(reviewServiceProvider);
    reviewService.checkAndRequestReview();
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const RootPageView(
          firstChild: BottomNavigationBarView(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomActionBar(
        leftItem: BottomActionBarItem(
          child: MeditoIcon(
            assetName: MeditoIcons.xmark,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onTap: () => Navigator.pop(context),
          semanticLabel: AppLocalizations.of(context)!.close,
        ),
        leftCenterItem: BottomActionBarItem(
          child: const SizedBox.shrink(),
          onTap: null,
        ),
        rightCenterItem: BottomActionBarItem(
          child: const SizedBox.shrink(),
          onTap: null,
        ),
        rightItem: BottomActionBarItem(
          child: MeditoIcon(
            assetName: MeditoIcons.home,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onTap: _navigateToHome,
          semanticLabel: AppLocalizations.of(context)!.home,
        ),
        layout: BottomActionBarLayout.edgeAligned,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              SlideTransition(
                position: _statsSlideAnimation,
                child: FadeTransition(
                  opacity: _statsFadeAnimation,
                  child: ref.watch(zenModeProvider)
                      ? const ZenModeAnimation()
                      : _buildStatsArea(),
                ),
              ),
              SlideTransition(
                position: _reminderSlideAnimation,
                child: FadeTransition(
                  opacity: _reminderFadeAnimation,
                  child: _buildReminderPrompt(),
                ),
              ),
              SlideTransition(
                position: _cardSlideAnimation,
                child: FadeTransition(
                  opacity: _cardFadeAnimation,
                  child: _buildCard(),
                ),
              ),
              // _buildFreezeRewardBanner(ref.watch(statsProvider).valueOrNull!),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: DonationWidget(),
    );
  }

  Widget _buildStatsArea() {
    var statsAsyncValue = ref.watch(statsProvider);

    return statsAsyncValue.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(child: Text('Error: $err')),
      ),
      data: (localAllStats) {
        var streak = localAllStats.streakCurrent;
        var daysMeditated = _getDaysMeditated(localAllStats.audioCompleted);
        var lastFiveDays = List.generate(
          5,
          (index) => DateTime.now().subtract(Duration(days: index)),
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              key: _animatedSwitcherKey,
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(streak),
                child: Text(
                  streak.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: dmSerif,
                        fontSize: 100,
                        fontWeight: FontWeight.w400,
                      ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            Text(
              AppLocalizations.of(context)!.dayStreak,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: teachers,
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    height: 1,
                    color: context.brandPurple,
                  ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              child: _buildDayLettersAndIcons(
                lastFiveDays,
                daysMeditated,
                key: ValueKey(daysMeditated.join()),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                AppLocalizations.of(context)!.dailyPracticeMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: teachers,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  List<String> _getDaysMeditated(List<LocalAudioCompleted>? audioCompleted) {
    return audioCompleted
            ?.map((audio) =>
                DateTime.fromMillisecondsSinceEpoch(audio.timestamp)
                    .toIso8601String()
                    .split('T')[0])
            .toList() ??
        [];
  }

  List<String> _getDaysWithStreakFreeze(LocalAllStats stats) {
    return stats.freezeUsageDates
        .map((timestamp) => DateTime.fromMillisecondsSinceEpoch(timestamp)
            .toIso8601String()
            .split('T')[0])
        .toList();
  }

  Widget _buildDayLettersAndIcons(
      List<DateTime> lastFiveDays, List<String> daysMeditated,
      {Key? key}) {
    lastFiveDays = lastFiveDays.reversed.toList();

    var statsData = ref.watch(statsProvider).value;
    var daysWithFreeze =
        statsData != null ? _getDaysWithStreakFreeze(statsData) : <String>[];

    var dayLetters = lastFiveDays.map((day) {
      switch (day.weekday) {
        case 1:
          return AppLocalizations.of(context)!.monday;
        case 2:
          return AppLocalizations.of(context)!.tuesday;
        case 3:
          return AppLocalizations.of(context)!.wednesday;
        case 4:
          return AppLocalizations.of(context)!.thursday;
        case 5:
          return AppLocalizations.of(context)!.friday;
        case 6:
          return AppLocalizations.of(context)!.saturday;
        case 7:
          return AppLocalizations.of(context)!.sunday;
        default:
          return '';
      }
    }).toList();

    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dayLetters.length, (index) {
        var day = lastFiveDays[index];
        var dayString = day.toIso8601String().split('T')[0];
        var isMeditated = daysMeditated.contains(dayString);
        var isFreeze = daysWithFreeze.contains(dayString);

        var isConsecutive = (isMeditated || isFreeze) &&
            (index > 0 &&
                    (daysMeditated.contains(lastFiveDays[index - 1]
                            .toIso8601String()
                            .split('T')[0]) ||
                        daysWithFreeze.contains(lastFiveDays[index - 1]
                            .toIso8601String()
                            .split('T')[0])) ||
                index < dayLetters.length - 1 &&
                    (daysMeditated.contains(lastFiveDays[index + 1]
                            .toIso8601String()
                            .split('T')[0]) ||
                        daysWithFreeze.contains(lastFiveDays[index + 1]
                            .toIso8601String()
                            .split('T')[0])));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayLetters[index],
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: teachers,
                      fontSize: 14,
                      fontWeight: (isMeditated || isFreeze)
                          ? FontWeight.w600
                          : FontWeight.w500,
                      height: 1.2,
                      color: isFreeze
                          ? ColorConstants.graphite
                          : isMeditated
                              ? context.brandPurple
                              : ColorConstants.moon,
                    ),
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isConsecutive)
                    _buildCircle(
                      36,
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                    ),
                  if (isFreeze)
                    MeditoIcon(
                      assetName: MeditoIcons.snow,
                      size: 32,
                      color: ColorConstants.graphite,
                    )
                  else if (isMeditated)
                    MeditoIcon(
                      assetName: MeditoIcons.checkCircleSolid,
                      size: 32,
                      color: context.brandPurple,
                    )
                  else
                    _buildCircle(32, ColorConstants.moon),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCircle(double size, Color colour) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colour,
      ),
    );
  }

  Future<void> _dismissReminderPromptForever() async {
    await ref.read(reminderPromptDismissedProvider.notifier).dismissForever();
    if (mounted) {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.reminderPromptDismissedMessage,
      );
    }
  }

  Widget _buildReminderPrompt() {
    final shouldShow = ref.watch(shouldShowReminderPromptProvider);
    final isReminderEnabled = ref.watch(reminderEnabledProvider);

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: 16,
      ),
      child: HomeGradientBorder(
        backgroundColor: Theme.of(context).cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MeditoIcon(
                  assetName: MeditoIcons.bell,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.smartReminders,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: teachers,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.dismiss,
                  icon: MeditoIcon(
                    assetName: MeditoIcons.xmark,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _dismissReminderPromptForever,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (!isReminderEnabled) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.enableNotificationsBody,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isReminderEnabled ? null : () => _enableReminders(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReminderEnabled
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: isReminderEnabled
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  isReminderEnabled
                      ? AppLocalizations.of(context)!.smartRemindersOn
                      : AppLocalizations.of(context)!.turnOnSmartReminders,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableReminders() async {
    try {
      final accepted = await PermissionHandler.requestAlarmPermission(context);
      if (!accepted || !mounted) {
        return;
      }

      final prefs = ref.read(sharedPreferencesProvider);
      final service = SmartRemindersService(
        prefs: prefs,
        reminders: ref.read(reminderProvider),
      );

      final time = await service.enable();
      await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
      await ref.read(reminderTimeProvider.notifier).setTime(time);

      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
          name: AnalyticsEventConstants.notificationsEnabled,
          parameters: {
            AnalyticsEventConstants.paramSource:
                AnalyticsEventConstants.sourceEndScreen,
          },
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Error enabling reminders - silently fail
    }
  }
}
