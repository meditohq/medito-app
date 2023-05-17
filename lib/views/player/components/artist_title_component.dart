import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class ArtistTitleComponent extends StatelessWidget {
  const ArtistTitleComponent({
    super.key,
    required this.sessionTitle,
    this.artistName,
    this.artistUrlPath,
    this.sessionTitleFontSize = 24,
    this.artistNameFontSize = 16,
    this.artistUrlPathFontSize = 13,
  });
  final String sessionTitle;
  final String? artistName, artistUrlPath;
  final double sessionTitleFontSize;
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
      sessionTitle,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
            fontFamily: ClashDisplay,
            color: ColorConstants.walterWhite,
            fontSize: sessionTitleFontSize,
            letterSpacing: 1,
          ),
    );
  }

  Padding _subtitle() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: MarkdownComponent(
        textAlign: WrapAlignment.start,
        body: '${artistName ?? ''} ${artistUrlPath ?? ''}',
        pFontSize: artistNameFontSize,
        aFontSize: artistUrlPathFontSize,
      ),
    );
  }
}
