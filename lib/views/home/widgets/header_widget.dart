import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'header/home_header_widget.dart';
import 'stats/streak_circle.dart';

class HeaderWidget extends ConsumerStatefulWidget {
  const HeaderWidget({
    super.key,
    required this.onStatsButtonTap,
    required this.greeting,
  });

  final String greeting;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: HomeHeaderWidget(
            greeting: widget.greeting,
          ),
        ),
        StreakCircle(
          onTap: widget.onStatsButtonTap,
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => false;
}
