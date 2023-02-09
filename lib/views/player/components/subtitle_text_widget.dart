import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SubtitleTextWidget extends StatelessWidget {
  final String? body;

  SubtitleTextWidget({Key? key, this.body}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: body ?? 'Loading...',
      onTapLink: _linkTap,
      shrinkWrap: true,
      padding: const EdgeInsets.all(0),
      styleSheet: buildMarkdownStyleSheet(context).copyWith(
        p: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: DmMono,
              letterSpacing: 1,
              color: ColorConstants.walterWhite.withOpacity(0.9),
            ),
        textAlign: WrapAlignment.center,
        a: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: DmMono,
            color: ColorConstants.walterWhite.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  void _linkTap(String text, String? href, String? title) {
    launchUrl(href);
  }
}
