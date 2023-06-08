import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class ArtistTitleWidget extends StatelessWidget {
  const ArtistTitleWidget({
    super.key,
    required this.meditationTitle,
    this.artistName,
    this.artistUrlPath,
    this.meditationTitleFontSize = 24,
    this.artistNameFontSize = 16,
    this.artistUrlPathFontSize = 13,
  });
  final String meditationTitle;
  final String? artistName, artistUrlPath;
  final double meditationTitleFontSize;
  final double artistNameFontSize;
  final double artistUrlPathFontSize;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context),
        _subtitle(),
      ],
    );
  }

  Text _title(BuildContext context) {
    return Text(
      meditationTitle,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
            fontFamily: ClashDisplay,
            color: ColorConstants.walterWhite,
            fontSize: meditationTitleFontSize,
            letterSpacing: 1,
          ),
    );
  }

  Padding _subtitle() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: MarkdownWidget(
        textAlign: WrapAlignment.start,
        body: '${artistName ?? ''} ${artistUrlPath ?? ''}',
        pFontSize: artistNameFontSize,
        aFontSize: artistUrlPathFontSize,
      ),
    );
  }
}
