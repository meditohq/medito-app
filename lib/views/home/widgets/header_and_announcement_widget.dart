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

class HeaderAndAnnouncementWidget extends ConsumerStatefulWidget {
  const HeaderAndAnnouncementWidget({
    super.key,
    required this.menuData,
    required this.announcementData,
    required this.statsData,
    required this.onStatsButtonTap,
  });

  final List<HomeMenuModel> menuData;
  final AnnouncementModel? announcementData;
  final StatsModel? statsData;
  final VoidCallback onStatsButtonTap;

  @override
  ConsumerState<HeaderAndAnnouncementWidget> createState() =>
      _HeaderAndAnnouncementWidgetState();
}

class _HeaderAndAnnouncementWidgetState
    extends ConsumerState<HeaderAndAnnouncementWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool isCollapsed = false;

  late CurvedAnimation curvedAnimation = CurvedAnimation(
    parent: AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..forward(),
    curve: Curves.easeInOut,
  );

  void _handleCollapse() {
    setState(() {
      isCollapsed = !isCollapsed;
    });
    curvedAnimation = CurvedAnimation(
      parent: AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1000),
      )..forward(),
      curve: Curves.easeInOut,
    );
  }

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
        if (widget.announcementData != null)
          _getAnnouncementBanner(widget.announcementData!),
      ],
    );
  }

  Widget _getAnnouncementBanner(AnnouncementModel data) {
    return SizeTransition(
      axisAlignment: -1,
      sizeFactor: isCollapsed
          ? Tween<double>(begin: 1.0, end: 0.0).animate(
              curvedAnimation,
            )
          : Tween<double>(begin: 0.0, end: 1.0).animate(
              curvedAnimation,
            ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: AnnouncementWidget(
          announcement: data,
          onPressedDismiss: _handleCollapse,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => false;
}
