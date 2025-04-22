import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_provider.dart';
import 'package:medito/providers/streak_freeze_suggestion_provider.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../row_item_widget.dart';

class StatsBottomSheetWidget extends ConsumerStatefulWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  ConsumerState<StatsBottomSheetWidget> createState() =>
      _StatsBottomSheetWidgetState();
}

class _StatsBottomSheetWidgetState extends ConsumerState<StatsBottomSheetWidget>
    with SingleTickerProviderStateMixin {
  bool _isCardVisible = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _fadeAndHideCard() {
    _animationController.forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isCardVisible = false;
        });
        ref.read(streakCircleProvider.notifier).markAsSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var statsAsync = ref.watch(statsProvider);
    var hasSeenStreakCircle = ref.watch(streakCircleProvider);

    return SafeArea(
      child: Container(
        decoration: bottomSheetBoxDecoration,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              height16,
              const HandleBarWidget(),
              height16,
              if (_isCardVisible)
                hasSeenStreakCircle.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (seen) {
                    if (seen) return const SizedBox.shrink();
                    return AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 0,
                        ),
                        child: Container(
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ColorConstants.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ColorConstants.white,
                              width: 1,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.solidRoundedFire,
                                    size: 20,
                                    color: ColorConstants.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    StringConstants.statsWelcomeTitle,
                                    style: TextStyle(
                                      color: ColorConstants.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: dmSans,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                StringConstants.statsWelcomeMessage,
                                style: TextStyle(
                                  color: ColorConstants.white,
                                  fontSize: 14,
                                  height: 1.4,
                                  fontFamily: dmSans,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: _fadeAndHideCard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorConstants.white,
                                    foregroundColor: ColorConstants.onyx,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Got it',
                                      style: TextStyle(fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              statsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                error: (error, stack) {
                  // If there was a previous successful state, display that instead of the error
                  if (statsAsync.hasValue) {
                    final stats = statsAsync.value!;
                    return _statsList(context, stats, ref);
                  } else {
                    // If there's no previous data, show the actual error state
                    return Center(
                      child: GestureDetector(
                        onTap: () => ref.read(statsProvider.notifier).refresh(),
                        child: HugeIcon(
                            icon: HugeIcons.strokeRoundedHelpCircle,
                            color: ColorConstants.white),
                      ),
                    );
                  }
                },
                data: (stats) {
                  // If the stats have a zero 'updated' timestamp, they're either initial empty stats
                  // or they haven't been properly fetched yet
                  final isPossiblyStillLoading = stats.updated == 0;

                  if (isPossiblyStillLoading) {
                    // Only try to refresh if it's the initial load
                    Future.microtask(
                        () => ref.read(statsProvider.notifier).refresh());
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  return _statsList(context, stats, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String title, String value) {
    return RowItemWidget(
      icon: MeditoHugeIcon(icon: title),
      iconColor: ColorConstants.white.toString(),
      trailingIconSize: 20,
      title: value,
      subTitle: title,
      hasUnderline: true,
      isTrailingIcon: false,
      titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
          ),
    );
  }

  String _formatTotalTimeListened(int milliseconds) {
    var hours = milliseconds ~/ (1000 * 60 * 60);
    var minutes = (milliseconds % (1000 * 60 * 60)) ~/ (1000 * 60);

    if (hours > 0) {
      var hourText =
          hours == 1 ? StringConstants.hourFull : StringConstants.hoursFull;
      var minuteText =
          minutes == 1 ? StringConstants.minute : StringConstants.minutes;
      return '$hours $hourText ${minutes.toString().padLeft(2, '0')} $minuteText';
    } else {
      var minuteText =
          minutes == 1 ? StringConstants.minute : StringConstants.minutes;
      return '$minutes $minuteText';
    }
  }

  Column _statsList(
    BuildContext context,
    LocalAllStats stats,
    WidgetRef ref,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: ColorConstants.onyx,
          child: Column(
            children: [
              _buildStatRow(
                context,
                StringConstants.consistencyScore,
                '${(stats.consistencyScore! * 100).round()}%',
              ),
              _buildStatRow(context, StringConstants.currentStreak,
                  '${stats.streakCurrent} ${stats.streakCurrent == 1 ? StringConstants.day : StringConstants.days}'),
              _buildStatRow(context, StringConstants.longestStreak,
                  '${stats.streakLongest} ${stats.streakLongest == 1 ? StringConstants.day : StringConstants.days}'),
              _buildStatRow(context, StringConstants.totalTracksCompleted,
                  '${stats.totalTracksCompleted}'),
              _buildStatRow(context, StringConstants.totalTimeListened,
                  _formatTotalTimeListened(stats.totalTimeListened)),
              _buildFreezeInfo(stats, context, ref),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Share.share(StringConstants.shareStatsText),
              icon: HugeIcon(
                icon: HugeIcons.solidRoundedShare08,
                size: 20,
                color: ColorConstants.white,
              ),
              label: Text(StringConstants.share),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.lightPurple,
                foregroundColor: ColorConstants.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreezeInfo(
    LocalAllStats stats,
    BuildContext context,
    WidgetRef ref,
  ) {
    final isDonor =
        ref.watch(meProvider).valueOrNull?.hasActiveSubscription ?? false;

    // Check if streak freeze feature is enabled
    final isStreakFreezeEnabled =
        ref.watch(featureFlagsProvider).isStreakFreezeEnabled;

    // Don't show streak freeze UI if feature is disabled or user is not a donor
    if (!isDonor || !isStreakFreezeEnabled) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '${stats.streakFreezes}/${stats.maxStreakFreezes} ${StringConstants.streakFreezesAvailable}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColorConstants.lightPurple,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (_canUseStreakFreeze(stats))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton(
              onPressed: () => _useStreakFreeze(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorConstants.lightPurple,
                foregroundColor: ColorConstants.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(StringConstants.useStreakFreeze),
            ),
          ),
      ],
    );
  }

  bool _canUseStreakFreeze(LocalAllStats stats) {
    // Check if user has streak freezes available and needs one
    if ((stats.streakFreezes ?? 0) <= 0) return false;

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    // Check if there was activity yesterday
    final hasActivityYesterday = stats.audioCompleted?.any((audio) {
          final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          return date.year == yesterday.year &&
              date.month == yesterday.month &&
              date.day == yesterday.day;
        }) ??
        false;

    // Check if a freeze was already used for yesterday
    final freezeUsedYesterday = stats.freezeUsageDates.any((timestamp) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day;
    });

    // Can use a freeze if no activity yesterday and no freeze already used
    return !hasActivityYesterday &&
        !freezeUsedYesterday &&
        stats.streakCurrent > 0;
  }

  void _useStreakFreeze(BuildContext context, WidgetRef ref) {
    // Check if streak freeze feature is enabled
    final isStreakFreezeEnabled =
        ref.read(featureFlagsProvider).isStreakFreezeEnabled;

    // Don't use streak freeze if feature is disabled
    if (!isStreakFreezeEnabled) return;

    ref.read(streakFreezeSuggestionProvider.notifier).useStreakFreeze();
    // Show a confirmation message
    showSnackBar(context, StringConstants.freezeUsedMessage);
  }
}
