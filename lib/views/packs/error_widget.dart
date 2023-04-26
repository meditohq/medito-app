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
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ErrorPacksWidget extends StatelessWidget {
  final onPressed;

  @override
  Widget build(BuildContext context) {
    var titleSmall = Theme.of(context).textTheme.titleSmall;
    var outlineButtonStyle = OutlinedButton.styleFrom(
      side: BorderSide(
        width: 1.0,
        color: ColorConstants.walterWhite,
        style: BorderStyle.solid,
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: Container(
            color: ColorConstants.deepNight,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  StringConstants.LOADING_ERROR,
                  textAlign: TextAlign.center,
                  style: titleSmall,
                ),
                Container(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      style: outlineButtonStyle,
                      onPressed: () {
                        createSnackBar(
                          StringConstants.RETRYING,
                          context,
                          color: ColorConstants.darkBGColor,
                        );
                        onPressed();
                      },
                      child: Text(
                        StringConstants.TRY_AGAIN,
                        style: titleSmall,
                      ),
                    ),
                    Container(width: 16),
                    OutlinedButton(
                      style: outlineButtonStyle,
                      onPressed: () => {
                        context.go(RouteConstants.collectionPath),
                      },
                      child: Text(
                        StringConstants.SHOW_DOWNLOADS,
                        style: titleSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ErrorPacksWidget({this.onPressed});
}
