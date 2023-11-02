import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marquee/marquee.dart';

class ArtistTitleWidget extends ConsumerWidget {
  const ArtistTitleWidget({
    super.key,
    required this.trackTitle,
    this.artistName,
    this.artistUrlPath,
    this.trackTitleFontSize = 24,
    this.artistNameFontSize = 14,
    this.artistUrlPathFontSize = 13,
    this.isPlayerScreen = false,
    this.titleHeight = 35,
  });
  final String trackTitle;
  final String? artistName, artistUrlPath;
  final double trackTitleFontSize;
  final double artistNameFontSize;
  final double artistUrlPathFontSize;
  final bool isPlayerScreen;
  final double titleHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context),
        if (artistName != null) _subtitle(context),
      ],
    );
  }

  Widget _title(BuildContext context) {
    return SizedBox(
      height: titleHeight,
      child: Marquee(
        text: trackTitle,
        style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
              fontFamily: ClashDisplay,
              color: ColorConstants.walterWhite,
              fontSize: trackTitleFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
        blankSpace: 40,
        velocity: 20,
      ),
    );
  }

  Padding _subtitle(BuildContext context) {
    var style = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFamily: DmMono,
          fontSize: artistNameFontSize,
          letterSpacing: 0,
          color: ColorConstants.graphite,
        );

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        child: Text(
          artistName ?? '',
          style: style,
        ),
        onTap: () {
          if (isPlayerScreen && artistUrlPath != null) {
            context.pop();
            var getCurrentLocation = GoRouter.of(context);
            var location = getCurrentLocation.location;
            if (location.contains(RouteConstants.webviewPath)) {
              context.pop();
            }
            location = getCurrentLocation.location;
            context.push(
              RouteConstants.webviewPath,
              extra: {'url': artistUrlPath},
            );
          }
        },
      ),
    );
  }
}
