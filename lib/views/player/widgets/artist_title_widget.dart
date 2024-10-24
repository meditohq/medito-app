import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final String? trackTitle;
  final String? artistName, artistUrlPath;
  final double trackTitleFontSize;
  final double artistNameFontSize;
  final double artistUrlPathFontSize;
  final bool isPlayerScreen;
  final double titleHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _title(context),
        if (artistUrlPath.isNotNullAndNotEmpty()) _subtitle(context),
      ],
    );
  }

  Widget _title(BuildContext context) {
    if (trackTitle?.isEmpty == true || trackTitle == null) {
      return SizedBox(height: titleHeight);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        trackTitle ?? '',
        textAlign: TextAlign.center,
        style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
              fontFamily: sourceSerif,
              color: ColorConstants.white,
              fontSize: trackTitleFontSize,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  InkWell _subtitle(BuildContext context) {
    var style = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFamily: dmMono,
          fontSize: artistNameFontSize,
          letterSpacing: 0,
          color: ColorConstants.graphite,
        );

    return InkWell(
      onTap: () => _handleArtistNameTap(),
      child: Text(
        artistName ?? '',
        style: style,
      ),
    );
  }

  void _handleArtistNameTap() async {
    if (isPlayerScreen && artistUrlPath != null) {
      await launchURLInBrowser(
        artistUrlPath!,
      );
    }
  }
}
