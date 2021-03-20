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

import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class MeditoAppBarWidget extends StatelessWidget with PreferredSizeWidget {
  const MeditoAppBarWidget(
      {Key key,
      this.title,
      this.titleWidget,
      this.transparent = false,
      this.hasCloseButton = false,
        this.actions,
      this.closePressed})
      : super(key: key);

  final Function closePressed;
  final Widget titleWidget;
  final bool hasCloseButton;
  final transparent;
  final actions;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppBar(
          // leading: null,  defaults to implied leading
          leading: hasCloseButton ? CloseButton(onPressed: closePressed ?? closePressed,) : null,
          centerTitle: true,
          actions: actions,
          elevation: 0,
          backgroundColor:
              transparent ? Colors.transparent : MeditoColors.moonlight,
          title: getTitleWidget(context)),
    );
  }

  Widget getTitleWidget(BuildContext context) {
    if (titleWidget == null) {
      return Text(title ?? '', style: Theme.of(context).textTheme.headline2);
    } else {
      return Row(
        children: [
          titleWidget,
        ],
      );
    }
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize => Size.fromHeight(56.0);
}
