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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ErrorPacksWidget extends StatelessWidget {
  final onPressed;
  final widget;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        widget,
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      color: MeditoColors.darkColor,
                      onPressed: () => onPressed(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Oops! There was an error.\n Tap to refresh',
                          style: Theme.of(context).textTheme.bodyText2,
                          textAlign: TextAlign.center,
                        ),
                      )),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ErrorPacksWidget({this.onPressed, this.widget});
}
