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

import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/widgets/packs/pack_list_item.dart';
import 'package:flutter/material.dart';

class ListItemWidget extends StatelessWidget {
  ListItemWidget(
      {Key key, this.title, this.subtitle, this.fileType, this.id, this.oldId})
      : super(key: key);

  final title;
  final oldId;
  final subtitle;
  final fileType;
  final id;

  @override
  Widget build(BuildContext context) {
    return PackListItemWidget(PackImageListItemData(
        title: title,
        subtitle: subtitle,
        colorPrimary: MeditoColors.intoTheNight,
        icon: getIcon(),
        coverSize: 56));
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

  Widget getAudioIcon() {
    if (checkListened(id, oldId: oldId)) {
      return Icon(
        Icons.check,
        color: MeditoColors.walterWhite,
      );
    } else {
      return Icon(
        Icons.play_circle_fill,
        color: MeditoColors.walterWhite,
      );
    }
  }

  Widget buildTextIcon() {
    return Icon(Icons.description, color: MeditoColors.walterWhite);
  }

  Widget buildFolderIcon() {
    return Icon(Icons.folder, color: MeditoColors.walterWhite);
  }
}
