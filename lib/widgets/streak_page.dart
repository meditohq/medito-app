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
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:Medito/widgets/nav_pills_widget.dart';
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
  Widget build(BuildContext context) {
    var list = [
      ListItem("Back", "", null, parentId: ""),
      ListItem("Stats", "", null, parentId: "...")
    ];

    return Scaffold(
      backgroundColor: MeditoColors.darkBGColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: NavPillsWidget(list: list, backPressed: _backPressed),
              ),
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
                          getStreakTile(getCurrentStreak(), 'Current Streak',
                              onClick: openEditDialog,
                              editable: true,
                              optionalText: UnitType.day),
                          getStreakTile(
                              getMinutesListened(), 'Minutes Listened',
                              optionalText: UnitType.min)
                        ],
                      ),
                    ),
                    //right
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          getStreakTile(getLongestStreak(), 'Longest Streak',
                              editable: true,
                              onClick: openResetDialog,
                              optionalText: UnitType.day),
                          getStreakTile(
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

  void _backPressed(String value) {
    Navigator.pop(context);
  }

  openEditDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: new ThemeData(
              primaryColor: MeditoColors.lightColorLine,
              accentColor: Colors.orange,
              hintColor: Colors.green),
          child: AlertDialog(
            shape: _roundedRectangleBorder(),
            backgroundColor: MeditoColors.darkBGColor,
            title: Text("How many days is your streak?",
                style: Theme.of(context).textTheme.headline),
            content: new TextField(
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .subtitle
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
                        shape: _roundedRectangleBorder(),
                        color: MeditoColors.darkColor,
                        child: Text(
                          'CANCEL',
                          style: Theme.of(context).textTheme.display2.copyWith(
                              color: MeditoColors.lightColor,
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
                        shape: _roundedRectangleBorder(),
                        color: MeditoColors.lightColor,
                        child: Text(
                          'SAVE',
                          style: Theme.of(context).textTheme.display2.copyWith(
                              color: MeditoColors.darkBGColor,
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
//                  color: MeditoColors.lightColor,
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
              primaryColor: MeditoColors.lightColorLine,
              accentColor: Colors.orange,
              hintColor: Colors.green),
          child: AlertDialog(
            shape: _roundedRectangleBorder(),
            backgroundColor: MeditoColors.darkBGColor,
            title: Text("Reset longest streak to your current streak?",
                style: Theme.of(context).textTheme.headline),
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
                        shape: _roundedRectangleBorder(),
                        color: MeditoColors.darkColor,
                        child: Text(
                          'CANCEL',
                          style: Theme.of(context).textTheme.display2.copyWith(
                              color: MeditoColors.lightColor,
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
                        shape: _roundedRectangleBorder(),
                        color: MeditoColors.lightColor,
                        child: Text(
                          'RESET',
                          style: Theme.of(context).textTheme.display2.copyWith(
                              color: MeditoColors.darkBGColor,
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

  RoundedRectangleBorder _roundedRectangleBorder() {
    return RoundedRectangleBorder(
      borderRadius: new BorderRadius.circular(12.0),
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
