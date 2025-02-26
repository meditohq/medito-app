import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_freeze_suggestion_provider.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/widgets/widgets.dart';

import '../row_item_widget.dart';
import '../share_btn/share_btn_widget.dart';

class StatsBottomSheetWidget extends ConsumerWidget {
  const StatsBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var statsAsync = ref.watch(statsProvider);
    var globalKey = GlobalKey();

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
                error: (error, stack) => Center(
                  child: GestureDetector(
                    onTap: () => ref.read(statsProvider.notifier).refresh(),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedHelpCircle,
                        color: ColorConstants.white),
                  ),
                ),
                data: (stats) => _statsList(context, globalKey, stats, ref),
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
      title: title,
      subTitle: value,
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
      return '$hours ${StringConstants.hours} ${minutes.toString().padLeft(2, '0')} ${StringConstants.minutes}';
    } else {
      return '$minutes ${StringConstants.minutes}';
    }
  }

  Column _statsList(
    BuildContext context,
    GlobalKey key,
    LocalAllStats stats,
    WidgetRef ref,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: key,
          child: Container(
            color: ColorConstants.onyx,
            child: Column(
              children: [
                _buildStatRow(context, StringConstants.currentStreak,
                    '${stats.streakCurrent} ${StringConstants.days}'),
                _buildStatRow(context, StringConstants.longestStreak,
                    '${stats.streakLongest} ${StringConstants.days}'),
                _buildStatRow(context, StringConstants.totalTracksCompleted,
                    '${stats.totalTracksCompleted}'),
                _buildStatRow(context, StringConstants.totalTimeListened,
                    _formatTotalTimeListened(stats.totalTimeListened)),
                _buildFreezeInfo(stats, context, ref),
              ],
            ),
          ),
        ),
        ShareBtnWidget(
          globalKey: key,
          shareText: StringConstants.shareStatsText,
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

    if (!isDonor) return const SizedBox.shrink();

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
    ref.read(streakFreezeSuggestionProvider.notifier).useStreakFreeze();
    // Show a confirmation message
    showSnackBar(context, StringConstants.freezeUsedMessage);
  }
}
