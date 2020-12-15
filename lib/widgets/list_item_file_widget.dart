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

import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';

class ListItemWidget extends StatelessWidget {
  ListItemWidget({Key key, this.item}) : super(key: key);
  final ListItem item;

  Widget buildFolderIcon() {
    return Icon(Icons.folder, color: MeditoColors.walterWhite);
  }

  Widget getAudioIcon() {
    return FutureBuilder<bool>(
        future: checkListened(item.id),
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
    return Row(
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
    );
  }

  Widget getTwoTextViewsInColumn(BuildContext context) {
    return Flexible(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.title,
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    .copyWith(fontSize: 18, height: 1.4)),
            item.description == null || item.description.isEmpty
                ? Container()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.subtitle1.copyWith(
                            fontSize: 14,
                            letterSpacing: 0.2,
                            fontWeight: FontWeight.w500,
                            color: MeditoColors.walterWhite.withOpacity(0.7)),
                      ),
                    ],
                  )
          ]),
    );
  }

  Widget getIcon() {
    if (item.type == ListItemType.folder) {
      return buildFolderIcon();
    }

    var iconWidget;

    switch (item.fileType) {
      case FileType.audio:
      case FileType.audiosetdaily:
      case FileType.audiosethourly:
      case FileType.both:
        iconWidget = getAudioIcon();
        break;
      case FileType.text:
        iconWidget = buildTextIcon();
        break;
    }

    return iconWidget;
  }
}
