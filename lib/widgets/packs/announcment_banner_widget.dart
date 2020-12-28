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

import 'package:Medito/data/welcome.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AnnouncementBanner extends StatefulWidget {
  AnnouncementBanner({Key key, this.data}) : super(key: key);
  final WelcomeContent data;

  @override
  _AnnouncementBannerState createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  var hidden = false;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !hidden,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildSpacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: MaterialBanner(
              backgroundColor: MeditoColors.darkMoon,
              content: Text(widget.data.content),
              leading: widget.data.showIcon
                  ? CircleAvatar(
                backgroundColor: parseColor(widget.data.primaryColor),
                child: SvgPicture.asset(
                  'assets/images/${widget.data.icon}.svg',
                  color: MeditoColors.darkMoon,
                ),
              )
                  : Container(),
              actions: [
                FlatButton(
                  child: const Text(
                    'DISMISS',
                    style: TextStyle(
                      color: MeditoColors.walterWhite,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      hidden = true;
                    });
                  },
                ),
                FlatButton(
                  child: Text(widget.data.buttonLabel.toUpperCase(),
                      style: TextStyle(
                          color: MeditoColors.walterWhite, letterSpacing: 0.2)),
                  onPressed: () {
                    switch (widget.data.buttonDestinationType.toLowerCase()) {
                      case 'folder':
                      case 'text':
                      case 'session-single':
                      case 'url':
                        launchUrl(widget.data.buttonDestinationLink);
                    }
                  },
                ),
              ],
            ),
          ),
          buildSpacer()
        ],
      ),
    );
  }

  Row buildSpacer() {
    return Row(
      children: [
        Expanded(child: Container(color: MeditoColors.moonlight, height: 1)),
      ],
    );
  }
}
