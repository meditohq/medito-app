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
    return Column(children: [_title(context), _subtitle(context)]);
  }

  Widget _title(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
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
      ),
    );
  }

  Widget _subtitle(BuildContext context) {
    var style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontFamily: dmMono,
      fontSize: artistNameFontSize,
      letterSpacing: 0,
      color: ColorConstants.white,
    );

    return SizedBox(
      height: 30, // Fixed height for subtitle
      child: Semantics(
        link: isPlayerScreen && artistUrlPath != null,
        button: isPlayerScreen && artistUrlPath != null,
        child: InkWell(
          onTap: () => _handleArtistNameTap(),
          child: Center(child: Text(artistName ?? '', style: style)),
        ),
      ),
    );
  }

  void _handleArtistNameTap() async {
    if (isPlayerScreen && artistUrlPath != null) {
      await launchURLInBrowser(artistUrlPath!);
    }
  }
}
