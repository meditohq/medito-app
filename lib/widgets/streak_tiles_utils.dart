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
        builder: (context, snapshot) {
          var unit;
          if (snapshot.hasData) {
            var value = int.parse(snapshot?.data);
            unit = getUnits(widget.optionalText, value);
          }
          return GestureDetector(
            onTap: widget.onClick,
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    color: MeditoColors.moonlight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(height: 4),
                        Text(widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context).textTheme.headline6.copyWith(fontSize: 18)),
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
                              padding: const EdgeInsets.only(
                                  left: 4.0, bottom: 7.0),
                              child: Text(unit ?? ''),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                widget.editable
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.edit,
                            size: 16.0,
                            color: MeditoColors.walterWhiteLine,
                          ),
                        ))
                    : Container(),
              ],
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
}

RoundedRectangleBorder roundedRectangleBorder() {
  return RoundedRectangleBorder(
    borderRadius: new BorderRadius.circular(12.0),
  );
}