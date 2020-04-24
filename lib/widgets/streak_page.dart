import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/widgets/nav_pills_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakWidget extends StatefulWidget {
  StreakWidget({Key key}) : super(key: key);

  @override
  _StreakWidgetState createState() {
    return _StreakWidgetState();
  }
}

class _StreakWidgetState extends State<StreakWidget> {
  SharedPreferences prefs;

  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        this.prefs = prefs;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var list = [
      ListItem("Back", "", null, parentId: ""),
      ListItem("Stats", "", null, parentId: "...")
    ];

    return Scaffold(
      backgroundColor: MeditoColors.darkBGColor,
      body: SafeArea(
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
                        getStreakTile(getCurrentStreak(prefs), 'Current Streak',
                            openEditDialog(), 'days'),
                        getStreakTile(getMinutesListened(prefs),
                            'Minutes Listened', null, 'mins')
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
                        getStreakTile(getLongestStreak(prefs), 'Longest Streak',
                            null, 'days'),
                        getStreakTile(
                            getNumSessions(prefs), 'Number of Sessions', null)
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget getStreakTile(Future future, String title, Function onClick,
      [String optionalText]) {
    return FutureBuilder<String>(
        future: future,
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                color: MeditoColors.darkColor,
              ),
              child: GestureDetector(
                onTap: onClick,
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
                          style: Theme.of(context).textTheme.title),
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        children: <Widget>[
                          Text(snapshot?.data ?? '0',
                              style: Theme.of(context)
                                  .textTheme
                                  .title
                                  .copyWith(fontSize: 34)),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(optionalText ?? ''),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        });
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
              FlatButton(
                child: Text(
                  "SAVE",
                  style: Theme.of(context).textTheme.body1,
                ),
                onPressed: () {
                  Navigator.pop(context,
                      _controller.text.length > 4 ? '999' : _controller.text);
                  _controller.text = '';
                },
              )
            ],
          ),
        );
      },
    ).then((val) {
      setState(() {
        if (val != null) {
          updateStreak(prefs, streak: val);
        }
      });
    });
  }
}
