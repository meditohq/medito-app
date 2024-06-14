import 'package:Medito/models/models.dart';
import 'package:Medito/views/home/widgets/stats/stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/colors/color_constants.dart';
import '../../../constants/styles/widget_styles.dart';
import '../../../models/stats/stats_model.dart';
import '../../../utils/utils.dart';
import 'announcement/announcement_widget.dart';
import 'header/home_header_widget.dart';

class HeaderWidget extends ConsumerStatefulWidget {

  const HeaderWidget({
    super.key,
    required this.menuData,
    required this.statsData,
    required this.onStatsButtonTap,
    required this.greeting,
  });

  final String greeting;
  final List<HomeMenuModel> menuData;
  final StatsModel? statsData;
  final VoidCallback onStatsButtonTap;

  @override
  ConsumerState<HeaderWidget> createState() =>
      _HeaderAndAnnouncementWidgetState();
}

class _HeaderAndAnnouncementWidgetState
    extends ConsumerState<HeaderWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return _buildMain();
  }

  Column _buildMain() {
    var mini = widget.statsData?.mini;
    var miniFirst = mini?.first;
    var miniSecond = mini?[1];

    return Column(
      children: [
        HomeHeaderWidget(
          greeting: widget.greeting,
          homeMenuModel: widget.menuData,
        ),
        height8,
        StatsRow(
          leftButtonIcon: IconData(
            formatIcon(miniFirst?.icon ?? ''),
            fontFamily: 'MaterialIcons',
          ),
          rightButtonIcon: IconData(
            formatIcon(miniSecond?.icon ?? ''),
            fontFamily: 'MaterialIcons',
          ),
          leftButtonIconColor: ColorConstants.walterWhite,
          rightButtonIconColor: ColorConstants.walterWhite,
          leftButtonText: miniFirst?.title ?? '',
          rightButtonText: miniSecond?.title ?? '',
          leftButtonClicked: () {
            widget.onStatsButtonTap();
          },
          rightButtonClicked: () {
            widget.onStatsButtonTap();
          },
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => false;
}
