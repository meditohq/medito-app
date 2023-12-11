import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'announcement/announcement_widget.dart';
import 'header/home_header_widget.dart';

class HeaderAndAnnouncementWidget extends ConsumerStatefulWidget {
  const HeaderAndAnnouncementWidget({super.key});

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
    var response = ref.watch(fetchHomeHeaderProvider);

    return response.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: (data) => _buildMain(data),
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchHomeHeaderProvider),
        isLoading: response.isLoading,
        isScaffold: false,
      ),
      loading: () => const HeaderAndAnnouncementShimmerWidget(),
    );
  }

  Column _buildMain(HomeHeaderModel data) {
    return Column(
      children: [
        HomeHeaderWidget(
          homeMenuModel: data.menu,
        ),
        _getAnnouncementBanner(data),
      ],
    );
  }

  Widget _getAnnouncementBanner(HomeHeaderModel data) {
    if (data.announcement != null) {
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
            announcement: data.announcement!,
            onPressedDismiss: _handleCollapse,
          ),
        ),
      );
    }

    return SizedBox();
  }

  @override
  bool get wantKeepAlive => false;
}
