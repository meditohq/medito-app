import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/colors/color_constants.dart';
import '../../constants/styles/widget_styles.dart';
import '../network_image_widget.dart';

class MeditoAppBarLarge extends StatefulWidget {
  const MeditoAppBarLarge({
    super.key,
    required this.scrollController,
    required this.title,
    required this.coverUrl,
  });

  final ScrollController scrollController;
  final String title;
  final String coverUrl;

  @override
  State<MeditoAppBarLarge> createState() => _MeditoAppBarLargeState();
}

class _MeditoAppBarLargeState extends State<MeditoAppBarLarge> {
  final topBarHeight = 300.0;
  final collapsedPadding = 72.0;
  final expandedPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    final scrollPosition = widget.scrollController.hasClients
        ? widget.scrollController.offset
        : 0.0;
    final scrollFactor = (scrollPosition / 240).clamp(0.0, 1.0);
    final titlePaddingDelta =
        (collapsedPadding - expandedPadding) * scrollFactor;
    final titlePadding = (expandedPadding + titlePaddingDelta).toDouble();

    return SliverAppBar.large(
      shadowColor: ColorConstants.ebony,
      surfaceTintColor: Colors.transparent,
      expandedHeight: topBarHeight,
      backgroundColor: ColorConstants.onyx,
      leading: IconButton(
        icon: Icon(Icons.close_rounded),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: _flexibleSpaceBar(
        titlePadding,
        widget.title,
        scrollFactor,
      ),
    );
  }

  FlexibleSpaceBar _flexibleSpaceBar(
    double titlePadding,
    String title,
    double scrollFactor,
  ) {
    return FlexibleSpaceBar(
      centerTitle: false,
      titlePadding: EdgeInsets.only(left: titlePadding, bottom: 17.0),
      title: _topBarTitle(title),
      background: _topBarBackground(scrollFactor, widget.coverUrl),
    );
  }

  Text _topBarTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).primaryTextTheme.titleLarge?.copyWith(
            fontFamily: DmSerif,
            color: ColorConstants.walterWhite,
          ),
    );
  }

  Opacity _topBarBackground(double scrollFactor, String coverUrl) {
    return Opacity(
      opacity: 1 - scrollFactor,
      child: NetworkImageWidget(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
          colors: [
            ColorConstants.black.withOpacity(0),
            ColorConstants.black.withOpacity(0.3),
          ],
        ),
        url: coverUrl,
        isCache: true,
      ),
    );
  }
}
