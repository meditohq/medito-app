import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'announcement/announcement_widget.dart';
import 'header/home_header_widget.dart';

class HeaderAndAnnouncementWidget extends ConsumerStatefulWidget {
  const HeaderAndAnnouncementWidget({
    super.key,
    required this.menuData,
    required this.announcementData,
  });

  final List<HomeMenuModel> menuData;
  final AnnouncementModel? announcementData;

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
    return Column(
      children: [
        HomeHeaderWidget(
          homeMenuModel: widget.menuData,
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
        padding: const EdgeInsets.only(top: 16.0),
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
