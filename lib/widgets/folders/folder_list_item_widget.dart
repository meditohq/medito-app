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

import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:flutter/material.dart';

class ListItemWidget extends StatelessWidget {
  ListItemWidget({Key key, this.title, this.subtitle, this.fileType, this.id, this.oldId})
      : super(key: key);

  final title;
  final oldId;
  final subtitle;
  final fileType;
  final id;

  Widget buildFolderIcon() {
    return Icon(Icons.folder, color: MeditoColors.walterWhite);
  }

  Widget getAudioIcon() {
    return FutureBuilder<bool>(
        future: checkListened(id, oldId: oldId),
        builder: (context, listened) {
          if (!listened.hasError && listened.hasData && listened.data) {
            return Icon(
              Icons.check_circle,
              color: MeditoColors.walterWhite,
            );
          } else {
            return Icon(
              Icons.headset,
              color: MeditoColors.walterWhite,
            );
          }
        });
  }

  Widget buildTextIcon() {
    return Icon(Icons.description, color: MeditoColors.walterWhite);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Opacity(
              opacity: 0.7,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: getIcon(),
              )),
          getTwoTextViewsInColumn(context)
        ],
      ),
    );
  }

  Widget getTwoTextViewsInColumn(BuildContext context) {
    return Flexible(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.headline4),
            subtitle == null || subtitle.isEmpty
                ? Container()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.subtitle1),
                    ],
                  )
          ]),
    );
  }

  Widget getIcon() {
    var iconWidget;

    switch (fileType) {
      case FileType.session:
        iconWidget = getAudioIcon();
        break;
      case FileType.text:
        iconWidget = buildTextIcon();
        break;
      case FileType.folder:
        iconWidget = buildFolderIcon();
        break;
    }

    return iconWidget;
  }
}
