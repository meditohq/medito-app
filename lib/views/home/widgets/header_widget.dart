import 'package:medito/views/home/widgets/stats/stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/colors/color_constants.dart';
import '../../../constants/styles/widget_styles.dart';
import '../../../models/stats/stats_model.dart';
import '../../../utils/utils.dart';
import 'header/home_header_widget.dart';

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

  Column _buildMain() {
    var mini = widget.statsData?.mini;
    var miniFirst = mini?.isNotEmpty == true ? mini?.first : const TilesModel(
      icon: '',
      color: '',
      title: '',
      subtitle: '',
    );
    var miniSecond = ((mini?.length ?? 0) > 1  == true) ? mini![1] : const TilesModel(
      icon: '',
      color: '',
      title: '',
      subtitle: '',
    );

    return Column(
      children: [
        HomeHeaderWidget(
          greeting: widget.greeting,
        ),
        height8,
        StatsRow(
          leftButtonIcon: IconData(
            formatIcon(miniFirst?.icon ?? ''),
            fontFamily: materialIcons,
          ),
          rightButtonIcon: IconData(
            formatIcon(miniSecond.icon),
            fontFamily: materialIcons,
          ),
          leftButtonIconColor: ColorConstants.walterWhite,
          rightButtonIconColor: ColorConstants.walterWhite,
          leftButtonText: miniFirst?.title ?? '',
          rightButtonText: miniSecond.title,
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
