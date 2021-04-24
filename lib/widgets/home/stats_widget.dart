import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/widgets/streak_tile_widget.dart';
import 'package:flutter/material.dart';

class StatsWidget extends StatefulWidget {
  @override
  _StatsWidgetState createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text('Stats',
              style: Theme.of(context).textTheme.headline3),
        ),
        SizedBox(
          height: 73,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            itemBuilder: (context, i) => statsItem(context, i),
            itemCount: 5,
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
          ),
        ),
        Container(height: 16)
      ],
    );
  }

  Widget statsItem(BuildContext context, int index) {
    switch (index) {
      case 0:
        return StreakTileWidget(
          getCurrentStreak(),
          'Current streak',
          onClick: openEditDialog,
          editable: true,
          optionalText: UnitType.day,
        );
      case 1:
        return StreakTileWidget(
          getMinutesListened(),
          'Listened',
          optionalText: UnitType.min,
        );
      case 2:
        return StreakTileWidget(
          getLongestStreak(),
          'Longest streak',
          editable: true,
          onClick: openResetDialog,
          optionalText: UnitType.day,
        );
      case 3:
        return StreakTileWidget(
          getNumSessions(),
          'Total',
          optionalText: UnitType.sessions,
        );
    }
    return Container();
  }

  void openEditDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
            primaryColor: MeditoColors.walterWhite,
          ),
          child: AlertDialog(
            backgroundColor: MeditoColors.moonlight,
            title: Text('How many days is your streak?',
                style: Theme.of(context).textTheme.headline4),
            content: TextField(
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  .copyWith(letterSpacing: 1.5),
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red))),
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
                      height: 38,
                      child: TextButton(
                        onPressed: _onCancelTap,
                        child: Text('CANCEL',
                            style: Theme.of(context).textTheme.subtitle1
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onSaveTap,
                        style: TextButton.styleFrom(
                            // shape: roundedRectangleBorder(),
                            primary: MeditoColors.walterWhite),
                        child: Text('SAVE',
                            style: Theme.of(context).textTheme.headline3
                            // .copyWith(fontWeight: FontWeight.bold),
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
    ).then((val) {
      setState(() {
        if (val != null) {
          updateStreak(manualStreak: val);
        }
      });
    });
  }

  void openResetDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
              primaryColor: MeditoColors.walterWhite,
              accentColor: Colors.orange,
              hintColor: Colors.green),
          child: AlertDialog(
            backgroundColor: MeditoColors.moonlight,
            title: Text('Reset longest streak to your current streak?',
                style: Theme.of(context).textTheme.headline4),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onCancelTap,
                        style: TextButton.styleFrom(
                            // shape: roundedRectangleBorder(),
                            primary: MeditoColors.moonlight),
                        child: Text('CANCEL',
                            style: Theme.of(context).textTheme.subtitle1
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onResetTap,
                        style: TextButton.styleFrom(
                            // shape: roundedRectangleBorder(),
                            primary: MeditoColors.walterWhite),
                        child: Text('RESET',
                            style: Theme.of(context).textTheme.headline3
                            // .copyWith(fontWeight: FontWeight.bold),
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
