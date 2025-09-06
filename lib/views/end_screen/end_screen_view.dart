import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/root/root_page_view.dart';

import 'widgets/donation_widget.dart';

class EndScreenView extends ConsumerStatefulWidget {
  final TrackModel trackModel;

  const EndScreenView({
    super.key,
    required this.trackModel,
  });

  @override
  ConsumerState<EndScreenView> createState() => _EndScreenViewState();
}

class _EndScreenViewState extends ConsumerState<EndScreenView> {
  final _animatedSwitcherKey = GlobalKey();
  bool _hasFiredHapticFeedback = false;
  final _analytics = FirebaseAnalyticsService();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'EndScreenView');
  }

  Future<void> _triggerHapticFeedback() async {
    if (_hasFiredHapticFeedback) return;

    _hasFiredHapticFeedback = true;
    final canVibrate = await Haptics.canVibrate();
    if (canVibrate) {
      await Haptics.vibrate(HapticsType.success);
    }
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
          child: HugeIcon(
            icon: HugeIcons.solidSharpMultiplicationSign,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onTap: () => Navigator.pop(context),
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
          child: HugeIcon(
            icon: HugeIcons.solidSharpHome01,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onTap: _navigateToHome,
        ),
        layout: BottomActionBarLayout.edgeAligned,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsArea(),
              _buildCard(),
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
        _hasFiredHapticFeedback = false;
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
                if (animation.status == AnimationStatus.forward &&
                    !_hasFiredHapticFeedback) {
                  _triggerHapticFeedback();
                }

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
                    color: ColorConstants.lightPurple,
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

    var statsData = ref.watch(statsProvider).valueOrNull;
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
                              ? ColorConstants.lightPurple
                              : ColorConstants.moon,
                    ),
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isConsecutive)
                    HugeIcon(
                      size: 36,
                      icon: HugeIcons.solidSharpCircle,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  if (isFreeze)
                    HugeIcon(
                        size: 32,
                        icon: HugeIcons.solidRoundedSnow,
                        color: ColorConstants.graphite)
                  else if (isMeditated)
                    HugeIcon(
                        size: 32,
                        icon: HugeIcons.solidSharpCheckmarkCircle02,
                        color: ColorConstants.lightPurple)
                  else
                    HugeIcon(
                        size: 32,
                        icon: HugeIcons.solidSharpCircle,
                        color: ColorConstants.moon),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
