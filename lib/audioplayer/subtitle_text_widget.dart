import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';

class SubtitleTextWidget extends StatelessWidget {
  final String html;

  TextStyle getStyle(BuildContext context) =>
      Theme.of(context).textTheme.headline1.copyWith(
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          color: MeditoColors.walterWhite.withOpacity(0.7),
          height: 1.4);

  SubtitleTextWidget({Key key, this.html}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            children: [
              Html(
                data: html != null ? '<p>$html</p>' : '<p>Loading...</p>',
                onLinkTap: _linkTap,
                shrinkWrap: true,
                style: {
                  'a': Style(color: Colors.white),
                  'html': Style(
                      alignment: Alignment.center, textAlign: TextAlign.center)
                },
              ),
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
