import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/text_themes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SubtitleTextWidget extends StatelessWidget {
  final String body;

  TextStyle getStyle(BuildContext context) =>
      Theme.of(context).textTheme.headline1.copyWith(
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          color: MeditoColors.walterWhite.withOpacity(0.7),
          height: 1.4);

  SubtitleTextWidget({Key key, this.body}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            children: [
              Markdown(
                  data: body ?? 'Loading...',
                  onTapLink: _linkTap,
                  shrinkWrap: true,
                  styleSheet: buildMarkdownStyleSheet(context)),
            ],
          ),
        ),
      ],
    );
  }

  void _linkTap(String url) {
    launchUrl(url);
  }
}
