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

import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';

class PackListItemWidget extends StatelessWidget {
  final PackImageListItemData data;

  PackListItemWidget(this.data);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          _getListItemLeadingImageWidget(),
          Container(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _getTitle(context),
                data.subtitle.isNotEmptyAndNotNull()
                    ? Container(height: 4)
                    : Container(),
                data.subtitle.isNotEmptyAndNotNull()
                    ? _getSubtitle(context)
                    : Container()
              ],
            ),
          ),
        ],
      ),
    );
  }

  Text _getSubtitle(BuildContext context) =>
      Text(data.subtitle ?? '', style: Theme.of(context).textTheme.subtitle1);

  Text _getTitle(BuildContext context) => Text(data.title ?? '',
      style: Theme.of(context).textTheme.headline4,
      maxLines: 1,
      overflow: TextOverflow.ellipsis);

  Widget _getListItemLeadingImageWidget() => ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: Container(
          color: data.colorPrimary,
          child: SizedBox(
              height: data.coverSize,
              width: data.coverSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _backgroundImageWidget(),
                  _coverImageWidget(),
                ],
              )),
        ),
      );

  Padding _coverImageWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: data.icon ?? getNetworkImageWidget(data.cover),
    );
  }

  Widget _backgroundImageWidget() {
    return data.backgroundImage.isNotEmptyAndNotNull()
        ? getNetworkImageWidget(data.backgroundImage)
        : Container();
  }
}

class PackImageListItemData {
  String? title;
  String? subtitle;
  String? cover;
  String? backgroundImage;
  Color? colorPrimary;
  double? coverSize;
  Widget? icon;

  PackImageListItemData(
      {this.title,
      this.subtitle,
      this.colorPrimary,
      this.cover,
      this.coverSize,
      this.icon,
      this.backgroundImage});
}
