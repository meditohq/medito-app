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

import 'package:Medito/network/packs/annoucement_bloc.dart';
import 'package:Medito/network/packs/announcement_reponse.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AnnouncementBanner extends StatefulWidget {
  AnnouncementBanner({Key key}) : super(key: key);

  @override
  _AnnouncementBannerState createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  var hidden = false;
  final _bloc = AnnouncementBloc();

  @override
  void initState() {
    super.initState();
    _bloc.fetchAnnouncement();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AnnouncementContent>(
        stream: _bloc.announcementController.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

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
                    content: _buildTextColumn(snapshot, context),
                    leading: snapshot.data.showIcon
                        ? buildCircleAvatar(snapshot)
                        : Container(),
                    actions: [
                      _buildDismissButton(),
                      _buildPositiveButton(snapshot),
                    ],
                  ),
                ),
                buildSpacer()
              ],
            ),
          );
        });
  }

  Column _buildTextColumn(
      AsyncSnapshot<AnnouncementContent> snapshot, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(snapshot.data.title),
        Text(snapshot.data.body, style: Theme.of(context).textTheme.subtitle1),
      ],
    );
  }

  CircleAvatar buildCircleAvatar(AsyncSnapshot<AnnouncementContent> snapshot) {
    return CircleAvatar(
      backgroundColor: parseColor(snapshot.data.colorPrimary),
      child: SvgPicture.asset(
        'assets/images/${snapshot.data.icon}.svg',
        color: MeditoColors.darkMoon,
      ),
    );
  }

  Padding _buildPositiveButton(AsyncSnapshot<AnnouncementContent> snapshot) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: TextButton(
        onPressed: () {
          _openLink(snapshot.data.buttonType, snapshot.data.buttonPath);
        },
        child: Text(snapshot.data.buttonLabel.toUpperCase(),
            style:
                TextStyle(color: MeditoColors.walterWhite, letterSpacing: 0.2)),
      ),
    );
  }

  TextButton _buildDismissButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          hidden = true;
        });
      },
      child: const Text(
        'DISMISS',
        style: TextStyle(
          color: MeditoColors.walterWhite,
          letterSpacing: 0.2,
        ),
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

  void _openLink(String buttonType, String buttonPath) {
    NavigationFactory.navigateToScreenFromString(
        buttonType, buttonPath, context);
  }
}
