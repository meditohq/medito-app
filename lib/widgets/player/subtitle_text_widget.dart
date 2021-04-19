import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/text_themes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SubtitleTextWidget extends StatelessWidget {
  final String body;

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
                  padding: null,
                  styleSheet: buildMarkdownStyleSheet(context).copyWith(
                      p: Theme.of(context).textTheme.subtitle1,
                      textAlign: WrapAlignment.center,
                      a: TextStyle(color: MeditoColors.meditoTextGrey))),
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
