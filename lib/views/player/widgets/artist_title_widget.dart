import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              fontFamily: SourceSerif,
              color: ColorConstants.walterWhite,
              fontSize: trackTitleFontSize,
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
        onTap: () => _handleArtistNameTap(context),
      ),
    );
  }

  void _handleArtistNameTap(BuildContext context) async {
    if (isPlayerScreen && artistUrlPath != null) {
      await handleNavigation(
        context: context,
        TypeConstants.url,
        [artistUrlPath],
      );
    }
  }
}
