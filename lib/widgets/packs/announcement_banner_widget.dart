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

import 'package:Medito/network/packs/announcement_bloc.dart';
import 'package:Medito/network/packs/announcement_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/packs/expand_animate_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AnnouncementBanner extends StatefulWidget {
  AnnouncementBanner({Key key}) : super(key: key);

  @override
  AnnouncementBannerState createState() => AnnouncementBannerState();
}

class AnnouncementBannerState extends State<AnnouncementBanner>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  var _hidden = false;
  final _bloc = AnnouncementBloc();

  @override
  void initState() {
    super.initState();
    _bloc.fetchAnnouncement(skipCache: true);
  }

  void refresh() {
    _bloc.fetchAnnouncement(skipCache: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<AnnouncementResponse>(
        stream: _bloc.announcementController.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return Container();
          }

          return FutureBuilder<bool>(
              future: _bloc
                  .shouldHideAnnouncement(snapshot.data?.timestamp.toString()),
              initialData: false,
              builder: (context, showSnapshot) {
                if (showSnapshot.data) {
                  return Container();
                }

                return ExpandedSection(
                  expand: !_hidden,
                  child: AnimatedOpacity(
                    onEnd: () => {
                      _bloc.saveAnnouncementID(
                          snapshot.data.timestamp.toString())
                    },
                    duration: Duration(milliseconds: 250),
                    opacity: _hidden ? 0 : 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildSpacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: MaterialBanner(
                            backgroundColor: MeditoColors.darkMoon,
                            content: _buildTextColumn(snapshot, context),
                            leading: snapshot.data.icon.isNotEmptyAndNotNull()
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
                  ),
                );
              });
        });
  }

  Column _buildTextColumn(
      AsyncSnapshot<AnnouncementResponse> snapshot, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(snapshot.data.body,
            style: Theme.of(context)
                .textTheme
                .subtitle1
                .copyWith(color: MeditoColors.walterWhite)),
      ],
    );
  }

  CircleAvatar buildCircleAvatar(AsyncSnapshot<AnnouncementResponse> snapshot) {
    return CircleAvatar(
      backgroundColor: parseColor(snapshot.data.colorPrimary),
      child: SvgPicture.asset(
        'assets/images/${snapshot.data.icon}.svg',
        color: MeditoColors.darkMoon,
      ),
    );
  }

  Padding _buildPositiveButton(AsyncSnapshot<AnnouncementResponse> snapshot) {
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
          _hidden = true;
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

  Widget buildSpacer() {
    return Divider(
      color: MeditoColors.moonlight,
      height: 1,
    );
  }

  void _openLink(String buttonType, String buttonPath) {
    NavigationFactory.navigateToScreenFromString(
        buttonType, buttonPath, context);
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
