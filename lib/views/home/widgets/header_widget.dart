import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/stats/stats_model.dart';
import 'header/home_header_widget.dart';
import 'stats/stats_row.dart';

class HeaderWidget extends ConsumerStatefulWidget {
  const HeaderWidget({
    super.key,
    required this.statsData,
    required this.onStatsButtonTap,
    required this.greeting,
  });

  final String greeting;
  final StatsModel? statsData;
  final VoidCallback onStatsButtonTap;

  @override
  ConsumerState<HeaderWidget> createState() =>
      _HeaderAndAnnouncementWidgetState();
}

class _HeaderAndAnnouncementWidgetState extends ConsumerState<HeaderWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return _buildMain();
  }

  Row _buildMain() {
    var mini = widget.statsData?.mini;
    var streakData = mini?.isNotEmpty == true
        ? mini?.first
        : const TilesModel(
            icon: '',
            color: '',
            title: '',
            subtitle: '',
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: HomeHeaderWidget(
            greeting: widget.greeting,
          ),
        ),
        StreakButton(
          text: streakData?.title ?? '',
          isStreakDoneToday: streakData?.isStreakDoneToday ?? false,
          onTap: widget.onStatsButtonTap,
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => false;
}
