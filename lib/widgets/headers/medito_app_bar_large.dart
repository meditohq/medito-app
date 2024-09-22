import 'package:medito/constants/constants.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MeditoAppBarLarge extends StatefulWidget {
  const MeditoAppBarLarge({
    super.key,
    required this.scrollController,
    required this.title,
    this.coverUrl,
    this.bgColor = ColorConstants.onyx,
    this.hasLeading = false,
  });

  final ScrollController scrollController;
  final String title;
  final String? coverUrl;
  final Color bgColor;
  final bool hasLeading;

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
    final titlePadding = (expandedPadding).toDouble();

    return SliverAppBar.large(
      shadowColor: ColorConstants.ebony,
      surfaceTintColor: ColorConstants.transparent,
      expandedHeight: topBarHeight,
      backgroundColor: ColorConstants.onyx,
      automaticallyImplyLeading: false,
      leading: widget.hasLeading ? const BackButton() : null,
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
            fontFamily: SourceSerif,
            fontWeight: FontWeight.w700,
            color: ColorConstants.white,
          ),
    );
  }

  Opacity _topBarBackground(double scrollFactor, String? coverUrl) {
    if (coverUrl != null) {
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
          shouldCache: true,
          errorWidget: SizedBox(),
        ),
      );
    }

    return Opacity(
      opacity: 1 - scrollFactor,
      child: Container(
        color: widget.bgColor,
      ),
    );
  }
}
