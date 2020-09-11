
import 'package:Medito/utils/colors.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubtitleTextWidget extends StatelessWidget {
  final MediaItem mediaItem;

  TextStyle getStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .headline1
      .copyWith(
      color: MeditoColors.newGrey,
      height: 1.3);

  SubtitleTextWidget({Key key, this.mediaItem}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              style: getStyle(context),
              text: mediaItem != null ? 'By ${mediaItem.extras['attrTitle']}' : "Loading...",
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final url =  mediaItem.extras['attrLinkSource'];
                  if (await canLaunch(url)) {
                    await launch(
                        url,
                        forceSafariVC: false,
                        forceWebView: true
                    );
                  }
                },
            ),
            TextSpan(
              style:getStyle(context),
              text: mediaItem != null ? ' under ${mediaItem.extras['attrName']}' : "",
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final url =  mediaItem.extras['attrLinkLicense'];
                  if (await canLaunch(url)) {
                    await launch(
                        url,
                        forceSafariVC: false,
                        forceWebView: true
                    );
                  }
                },
            ),
          ],
        ));
  }
}
