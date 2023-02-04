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

import 'package:Medito/components/headers/collapsible_header_component.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/views/session_options/components/session_buttons.dart';
import 'package:flutter/material.dart';

class SessionOptionsScreen extends StatefulWidget {
  final String? id;
  final Screen? screenKey;

  SessionOptionsScreen({Key? key, this.id, this.screenKey}) : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => refresh(),
      child: Scaffold(
        body: CollapsibleHeaderComponent(
          bgImage: AssetConstants.dalle,
          title: 'Gratitude for nature',
          description:
              'This meditation focuses on cultivating gratitude for nature and recognising our connection to it. This can foster a real sense of belonging, happiness and contentment.',
          children: [
            mainContent(),
          ],
        ),
      ),
    );
  }

  Widget mainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24),
          Text(
            'Select a guide / duration',
            style: Theme.of(context)
                .primaryTextTheme
                .bodyText1
                ?.copyWith(color: MeditoColors.newGrey, fontFamily: DmSans),
          ),
          height16,
          SessionButtons()
        ],
      ),
    );
  }

  Future<void> refresh() async {}
}
