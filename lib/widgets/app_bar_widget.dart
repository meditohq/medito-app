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

class MeditoAppBarWidget extends StatefulWidget {
  const MeditoAppBarWidget(
      {Key key,
      this.title,
      this.backPressed,
      this.paddingBelow,
      this.transparent = false})
      : super(key: key);
  final bool paddingBelow;
  final transparent;
  final String title;
  final ValueChanged<String> backPressed;

  @override
  _MeditoAppBarWidgetState createState() => new _MeditoAppBarWidgetState();
}

class _MeditoAppBarWidgetState extends State<MeditoAppBarWidget>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor:
              widget.transparent ? Colors.transparent : MeditoColors.moonlight,
          title: Text(widget.title,
              style: Theme.of(context).textTheme.headline2.copyWith(
                  letterSpacing: 0.1,
                  fontSize: 18,
                  fontWeight: FontWeight.w600))),
    );
  }
}
