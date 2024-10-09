import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/stats_provider.dart';
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
                    onTap: () => ref.refresh(statsProvider),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedHelpCircle,
                        color: ColorConstants.white),
                  ),
                ),
                data: (stats) => _statsList(context, globalKey, stats),
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
            fontFamily: DmSans,
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
}
