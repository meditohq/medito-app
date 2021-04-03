/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';

class ThankYouWidget extends StatefulWidget {
  @override
  _ThankYouWidgetState createState() => _ThankYouWidgetState();
}

class _ThankYouWidgetState extends State<ThankYouWidget> {
  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.DONATION_PAGE_3);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _close();
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            MeditoAppBarWidget(
              hasCloseButton: true,
              closePressed: _close,
              transparent: true,
              titleWidget: SvgPicture.asset(
                'assets/images/medito.svg',
                height: 16,
              ),
            ),
            SingleChildScrollView(
              child: SafeArea(
                minimum: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/hearts.svg',
                      height: 200,
                      width: 176,
                    ),
                    Container(height: 32),
                    Text(
                      'Thank you',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headline4.copyWith(
                          color: MeditoColors.walterWhite,
                          fontWeight: FontWeight.bold),
                    ),
                    Container(height: 16),
                    Text(
                      'With your help we can continue building a more mindful world. We’re here for you. Thanks for being here for us.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText2
                          .copyWith(height: 1.5),
                    ),
                    Container(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            child: TextButton(
                              onPressed: _tellUs,
                              style: TextButton.styleFrom(
                                backgroundColor: MeditoColors.peacefulBlue,
                              ),
                              child: Text('Tell us why you\'ve donated',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: MeditoColors.peacefulPink,
                              ),
                              onPressed: _share,
                              child: Text(
                                  'Tell your friends you\'ve helped Medito',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black)),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _close() {
    Navigator.pushNamed(context, '/nav');
  }

  void _tellUs() async {
    var url = 'https://meditofoundation.typeform.com/to/WLTNT8h1';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _share() {
    Share.share(
        'I just donated to @meditohq to help build a more mindful world ❤️ Join me on their 100% free meditation app https://meditofoundation.org');
    return null;
  }
}
