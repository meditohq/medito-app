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

import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class MeditoAppBarSmall extends StatelessWidget implements PreferredSizeWidget {
  const MeditoAppBarSmall({
    Key? key,
    this.title,
    this.titleWidget,
    this.isTransparent = false,
    this.hasCloseButton = false,
    this.actions,
    this.closePressed,
  }) : super(key: key);

  final void Function()? closePressed;
  final Widget? titleWidget;
  final bool hasCloseButton;
  final bool isTransparent;
  final List<Widget>? actions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: hasCloseButton
          ? CloseButton(onPressed: closePressed ?? closePressed)
          : null,
      centerTitle: true,
      actions: actions,
      elevation: 0,
      backgroundColor: isTransparent ? Colors.transparent : ColorConstants.onyx,
      title: getTitleWidget(context),
    );
  }

  Widget getTitleWidget(BuildContext context) {
    return titleWidget == null
        ? Text(title ?? '', style: Theme.of(context).textTheme.displayLarge)
        : Row(children: [titleWidget ?? Container()]);
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0);
}
