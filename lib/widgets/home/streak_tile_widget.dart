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
import 'package:Medito/utils/stats_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class StreakTileWidget extends StatefulWidget {
  StreakTileWidget(this.future, this.title,
      {Key key, this.onClick, this.optionalText, this.editable = false})
      : super(key: key);

  final Future future;
  final String title;
  final Function onClick;
  final UnitType optionalText;
  final bool editable;

  @override
  _StreakTileWidgetState createState() => _StreakTileWidgetState();
}

class _StreakTileWidgetState extends State<StreakTileWidget> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: widget.future,
        initialData: '0',
        builder: (context, snapshot) {
          var unit;
          if (snapshot.hasData) {
            var value = int.parse(snapshot?.data);
            unit = getUnits(widget.optionalText, value);
          }
          return InkWell(
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
            splashColor: MeditoColors.softGrey,
            onTap: widget.onClick,
            child: Ink(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _getDataTextWidget(snapshot, unit, context),
                    SizedBox(height: 6),
                    getDescriptionWidget(context)
                  ],
                ),
              ),
            ),
          );
        });
  }

  Text _getDataTextWidget(
      AsyncSnapshot<String> snapshot, unit, BuildContext context) {
    return Text(
      (snapshot.hasData ? _formatSnapshotData(snapshot) : '') + unit ??
          '',
      style: Theme.of(context).textTheme.headline5,
      overflow: TextOverflow.fade,
      maxLines: 2,
    );
  }

  Text getDescriptionWidget(BuildContext context) {
    return Text(widget.title,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.subtitle1);
  }

  String _formatSnapshotData(AsyncSnapshot<String> snapshot) {
    var value = snapshot?.data ?? '0';
    if (value.length > 5) {
      return '999+';
    }
    return value;
  }
}

RoundedRectangleBorder roundedRectangleBorder() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6.0),
  );
}
