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

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/streak_tiles_utils.dart';
import 'package:flutter/material.dart';

class StreakWidget extends StatefulWidget {
  StreakWidget({Key key}) : super(key: key);

  @override
  _StreakWidgetState createState() {
    return _StreakWidgetState();
  }
}

class _StreakWidgetState extends State<StreakWidget> {
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.STREAK_PAGE);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MeditoAppBarWidget(title: "Stats"),
              Container(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    //left
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          StreakTileWidget(getCurrentStreak(), 'Current Streak',
                              onClick: openEditDialog,
                              editable: true,
                              optionalText: UnitType.day),
                          Container(height: 16),
                          StreakTileWidget(
                              getMinutesListened(), 'Minutes Listened',
                              optionalText: UnitType.min)
                        ],
                      ),
                    ),
                    Container(width: 16),
                    //right
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          StreakTileWidget(getLongestStreak(), 'Longest Streak',
                              editable: true,
                              onClick: openResetDialog,
                              optionalText: UnitType.day),
                          Container(height: 16),
                          StreakTileWidget(
                            getNumSessions(),
                            'Number of Sessions',
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // void _backPressed(String value) {
  //   Navigator.pop(context);
  // }

  openEditDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: new ThemeData(
            primaryColor: MeditoColors.walterWhite,
          ),
          child: AlertDialog(
            shape: roundedRectangleBorder(),
            backgroundColor: MeditoColors.moonlight,
            title: Text("How many days is your streak?",
                style: Theme.of(context).textTheme.headline5),
            content: new TextField(
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  .copyWith(letterSpacing: 1.5),
              decoration: new InputDecoration(
                  border: new OutlineInputBorder(
                      borderSide: new BorderSide(color: Colors.red))),
              keyboardType: TextInputType.number,
              autofocus: true,
              controller: _controller,
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Container(
                      height: 48,
                      child: FlatButton(
                        onPressed: _onCancelTap,
                        child: Text(
                          'CANCEL',
                          style: Theme.of(context).textTheme.headline3.copyWith(
                              color: MeditoColors.walterWhite,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 48,
                      child: FlatButton(
                        onPressed: _onSaveTap,
                        shape: roundedRectangleBorder(),
                        color: MeditoColors.walterWhite,
                        child: Text(
                          'SAVE',
                          style: Theme.of(context).textTheme.headline3.copyWith(
                              color: MeditoColors.darkMoon,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
//
//                FlatButton(
//                  shape: RoundedRectangleBorder(
//                    borderRadius: new BorderRadius.circular(12.0),
//                  ),
//                  color: MeditoColors.walterWhite,
//                  child: Text(
//                    "SAVE",
//                    style: Theme.of(context).textTheme.body1.copyWith(color: MeditoColors.darkBGColor),
//                  ),
//                  onPressed: () {
//                    Navigator.pop(context, _controller.text);
//                    _controller.text = '';
//                  },
//                ),
              )
            ],
          ),
        );
      },
    ).then((val) {
      setState(() {
        if (val != null) {
          updateStreak(streak: val);
        }
      });
    });
  }

  openResetDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: new ThemeData(
              primaryColor: MeditoColors.walterWhite,
              accentColor: Colors.orange,
              hintColor: Colors.green),
          child: AlertDialog(
            shape: roundedRectangleBorder(),
            backgroundColor: MeditoColors.moonlight,
            title: Text("Reset longest streak to your current streak?",
                style: Theme.of(context).textTheme.headline5),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Container(
                      height: 48,
                      child: FlatButton(
                        onPressed: _onCancelTap,
                        shape: roundedRectangleBorder(),
                        color: MeditoColors.moonlight,
                        child: Text(
                          'CANCEL',
                          style: Theme.of(context).textTheme.headline3.copyWith(
                              color: MeditoColors.walterWhite,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 48,
                      child: FlatButton(
                        onPressed: _onResetTap,
                        shape: roundedRectangleBorder(),
                        color: MeditoColors.walterWhite,
                        child: Text(
                          'RESET',
                          style: Theme.of(context).textTheme.headline3.copyWith(
                              color: MeditoColors.moonlight,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _onResetTap() {
    setLongestStreakToCurrentStreak();
    Navigator.pop(context, _controller.text);
    setState(() {});
  }

  void _onSaveTap() {
    Navigator.pop(context, _controller.text);
    _controller.text = '';
  }

  void _onCancelTap() {
    Navigator.pop(context);
    _controller.text = '';
  }
}
