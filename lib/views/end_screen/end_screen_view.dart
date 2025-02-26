import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    Future.delayed(const Duration(seconds: 1), () {
      ref.read(statsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        showCloseIcon: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsArea(),
              _buildCard(),
              _buildFreezeRewardBanner(ref.watch(statsProvider).valueOrNull!),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildCard() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: padding16),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: DonationWidget(),
          ),
        ],
      ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: dmSerif,
                    fontSize: 100,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            const Text(
              StringConstants.dayStreak,
              style: TextStyle(
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                StringConstants.dailyPracticeMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
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
            .map((timestamp) =>
                DateTime.fromMillisecondsSinceEpoch(timestamp)
                    .toIso8601String()
                    .split('T')[0])
            .toList();
  }

  Widget _buildDayLettersAndIcons(
      List<DateTime> lastFiveDays, List<String> daysMeditated,
      {Key? key}) {
    lastFiveDays = lastFiveDays.reversed.toList();
    
    var statsData = ref.watch(statsProvider).valueOrNull;
    var daysWithFreeze = statsData != null 
        ? _getDaysWithStreakFreeze(statsData) 
        : <String>[];

    var dayLetters = lastFiveDays.map((day) {
      switch (day.weekday) {
        case 1:
          return StringConstants.monday;
        case 2:
          return StringConstants.tuesday;
        case 3:
          return StringConstants.wednesday;
        case 4:
          return StringConstants.thursday;
        case 5:
          return StringConstants.friday;
        case 6:
          return StringConstants.saturday;
        case 7:
          return StringConstants.sunday;
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
                style: TextStyle(
                  fontFamily: teachers,
                  fontSize: 14,
                  fontWeight: (isMeditated || isFreeze) ? FontWeight.w600 : FontWeight.w500,
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
                      color: Colors.white,
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

  Widget _buildFreezeRewardBanner(LocalAllStats stats) {
    final isDonor =
        ref.watch(meProvider).valueOrNull?.hasActiveSubscription ?? false;
    final currentStreak = stats.streakCurrent;
    final freezesEarned = currentStreak > 0 && currentStreak % 7 == 0 ? 2 : 0;

    if (!isDonor || freezesEarned == 0) return const SizedBox.shrink();

    return FutureBuilder(
      future: _hasAwardedFreezes(stats, freezesEarned),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorConstants.lightPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You earned $freezesEarned streak freezes!',
                style: TextStyle(
                  color: ColorConstants.lightPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<bool> _hasAwardedFreezes(
      LocalAllStats stats, int freezesEarned) async {
    final currentStreak = stats.streakCurrent;
    if (freezesEarned == 0) return false;

    final lastAwardedStreak = await SharedPreferences.getInstance()
        .then((prefs) => prefs.getInt('last_freeze_award_streak') ?? 0);

    if (currentStreak > lastAwardedStreak && currentStreak % 7 == 0) {
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('last_freeze_award_streak', currentStreak);
      });
      return true;
    }
    return false;
  }
}
