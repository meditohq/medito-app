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

Widget getStreakTile(Future future, String title,
    {Function onClick, UnitType optionalText, bool editable = false}) {
  return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        var unit;
        if (snapshot.hasData) {
          var value = int.parse(snapshot?.data);
          unit = getUnits(optionalText, value);
        }
        return GestureDetector(
          onTap: onClick,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    color: MeditoColors.darkColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(height: 4),
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context).textTheme.headline6),
                        Wrap(
                          direction: Axis.horizontal,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: <Widget>[
                            Text(
                              _formatSnapshotData(snapshot),
                              style: Theme.of(context)
                                  .textTheme
                                  .headline6
                                  .copyWith(fontSize: 34),
                              overflow: TextOverflow.fade,
                              maxLines: 1,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4.0, bottom: 5.0),
                              child: Text(unit ?? ''),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                editable
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.edit,
                            size: 16.0,
                            color: MeditoColors.lightColorLine,
                          ),
                        ))
                    : Container(),
              ],
            ),
          ),
        );
      });
}

String _formatSnapshotData(AsyncSnapshot<String> snapshot) {
  var value = snapshot?.data ?? '0';
  if (value.length > 5) {
    return '999+';
  }
  return value;
}

//Widget wrapWithStreakInkWell(Widget w) {
//  return Material(
//    color: Colors.white.withOpacity(0.0),
//    child: InkWell(
//        splashColor: MeditoColors.lightColor,
//        onTap: () => _onStreakTap(),
//        borderRadius: BorderRadius.circular(16.0),
//        child: w),
//  );
//}
