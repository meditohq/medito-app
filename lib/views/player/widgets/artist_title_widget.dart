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
        child: Semantics(
          header: true,
          child: Text(
            trackTitle ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
              fontFamily: googleSans,
              color: ColorConstants.white,
              fontSize: trackTitleFontSize,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtitle(BuildContext context) {
    var style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontFamily: googleSans,
      fontSize: artistNameFontSize,
      letterSpacing: 0,
      color: ColorConstants.white,
    );

    final name = artistName ?? '';
    final url = artistUrlPath ?? '';
    final hasLink = isPlayerScreen && url.isNotEmpty;

    // Timers have no narrator: keep the row's space but no empty focus stop.
    // The name is a link only when there's somewhere to go.
    return SizedBox(
      height: 30, // Fixed height for subtitle
      child: name.isEmpty
          ? null
          : Semantics(
              link: hasLink,
              child: InkWell(
                onTap: hasLink ? () => launchURLInBrowser(url) : null,
                child: Center(child: Text(name, style: style)),
              ),
            ),
    );
  }
}
