import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildAttributionsAndDownloadButtonView(
    BuildContext context,
    String downloadURL,
    var contentText,
    var licenseTitle,
    var sourceUrl,
    var licenseName,
    String licenseURL,
    bool showDownloadButton) {
  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 24),
                  child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: getEdgeInsets(1, 1),
                        decoration: getBoxDecoration(1, 1,
                            color: MeditoColors.darkBGColor),
                        child: getTextLabel("← Go back", 1, 1, context),
                      )),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          color: MeditoColors.darkBGColor,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 20, bottom: 16.0, left: 16, right: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                contentText,
                                style: Theme.of(context).textTheme.display3,
                              ),
                              getAttrWidget(context, licenseTitle, sourceUrl,
                                  licenseName, licenseURL),
                              (showDownloadButton != null && showDownloadButton)
                                  ? _buildDownloadButton(context, downloadURL)
                                  : Container(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Container getAttrWidget(BuildContext context, licenseTitle, sourceUrl,
    licenseName, String licenseURL) {
  return Container(
    padding: EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
    child: new RichText(
      textAlign: TextAlign.center,
      text: new TextSpan(
        children: [
          new TextSpan(
            text: 'From '.toUpperCase(),
            style: Theme.of(context).textTheme.display4,
          ),
          new TextSpan(
            text: licenseTitle?.toUpperCase(),
            style: Theme.of(context).textTheme.body2,
            recognizer: new TapGestureRecognizer()
              ..onTap = () {
                launch(sourceUrl);
              },
          ),
          new TextSpan(
            text: ' / License: '.toUpperCase(),
            style: Theme.of(context).textTheme.display4,
          ),
          new TextSpan(
            text: licenseName?.toUpperCase(),
            style: Theme.of(context).textTheme.body2,
            recognizer: new TapGestureRecognizer()
              ..onTap = () {
                launch(licenseURL);
              },
          ),
        ],
      ),
    ),
  );
}

Widget _buildDownloadButton(BuildContext context, String url) {
  return FlatButton.icon(
    color: MeditoColors.darkColor,
    onPressed: () => _launchDownload(url),
    icon: Icon(
      Icons.cloud_download,
      color: MeditoColors.lightColor,
    ),
    label: Text(
      'DOWNLOAD',
      style: Theme.of(context).textTheme.display2,
    ),
  );
}

_launchDownload(String url) {
  Tracking.trackEvent(Tracking.PLAYER, Tracking.AUDIO_DOWNLOAD, url);
  launch(url.replaceAll(' ', '%20'));
}
