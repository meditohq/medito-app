import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/donation_widget.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../providers/stats_provider.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.invalidate(fetchDonationPageProvider);
    ref.invalidate(statsProvider);
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
            Text(
              streak.toString(),
              style: const TextStyle(
                fontFamily: dmSerif,
                fontSize: 100,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.left,
            ),
            const Text(
              StringConstants.dayStreak,
              style: TextStyle(
                  fontFamily: teachers,
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  color: ColorConstants.lightPurple),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 24),
            _buildDayLettersAndIcons(lastFiveDays, daysMeditated),
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

  Widget _buildDayLettersAndIcons(
      List<DateTime> lastFiveDays, List<String> daysMeditated) {
    lastFiveDays = lastFiveDays.reversed.toList();

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
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dayLetters.length, (index) {
        DateTime day = lastFiveDays[index];
        var isMeditated =
            daysMeditated.contains(day.toIso8601String().split('T')[0]);
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
                  fontWeight: isMeditated ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                  color: isMeditated
                      ? ColorConstants.lightPurple
                      : ColorConstants.moon,
                ),
              ),
              const SizedBox(height: 4),
              isMeditated
                  ? HugeIcon(
                      size: 32,
                      icon: HugeIcons.solidSharpCheckmarkCircle02,
                      color: ColorConstants.lightPurple)
                  : HugeIcon(
                      size: 32,
                      icon: HugeIcons.solidSharpCircle,
                      color: ColorConstants.moon),
            ],
          ),
        );
      }),
    );
  }
}
