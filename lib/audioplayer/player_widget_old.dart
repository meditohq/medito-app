import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:flutter/material.dart';

import '../utils/colors.dart';
import '../viewmodel/list_item.dart';

class PlayerWidget extends StatefulWidget {
  PlayerWidget(
      {Key key, this.fileModel, this.showReadMoreButton, this.readMorePressed})
      : super(key: key);
  final ListItem fileModel;
  final showReadMoreButton;
  final VoidCallback readMorePressed;

  @override
  _PlayerWidgetState createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  static Duration position;
  static Duration maxDuration;

  Duration duration = Duration(milliseconds: 1);
  Duration currentPlaybackPosition = Duration.zero;
  double selectedValue = 2.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
//      backgroundColor: MeditoColors.darkColor,
      backgroundColor: MeditoColors.darkColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
                child: DecoratedBox(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: getReadMoreTextWidget()),
                    ],
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    color: MeditoColors.darkColor,
                    borderRadius: BorderRadius.all(Radius.circular(16.0)),
                  ),
                )),
            SliderTheme(
              data: SliderThemeData(
                thumbColor: MeditoColors.lightColor,
                trackHeight: 4,
              ),
              child: Slider(
                value: selectedValue.toDouble(),
                activeColor: MeditoColors.lightColor,
                inactiveColor: MeditoColors.darkColor,
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() => selectedValue = value);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '00:00',
                      style: Theme.of(context).textTheme.subhead,
                    ),
                    Text('00:22',
                        style: Theme.of(context).textTheme.subhead),
                  ]),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: FlatButton(
                    child: Icon(
                      Icons.close,
                      color: MeditoColors.lightColor,
                    ),
                    color: MeditoColors.darkColor,
                    onPressed: pressed,
                  ),
                ),
                Container(width: 16),
                Expanded(
                  child: FlatButton(
                    child: Icon(Icons.play_arrow,
                        color: MeditoColors.darkColor),
                    color: MeditoColors.lightColor,
                    onPressed: pressed,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget getReadMoreTextWidget() {
    var title = "title";
    var readMoreText = "titsdfsdfsdle";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.title),
            Container(height: 8.0),
            Text(readMoreText, style: Theme.of(context).textTheme.subhead),
          ],
        ),
      ),
    );
  }

  // Seek to a point in seconds
  Future<void> seekTo(double milliseconds) async {
    setState(() {
      currentPlaybackPosition = Duration(milliseconds: milliseconds.toInt());
    });
//    _audioPlayer.seekTo(milliseconds / 1000);
  }

  void pressed() {
    print('pressss');
  }

  void _pressed(double d) {
    print('pressss $d');
  }

  buildGoBackPill() {
    return GestureDetector(
        onTap: () {
          //todo id here
          Tracking.trackEvent(
              Tracking.BREADCRUMB, Tracking.BREADCRUMB_TAPPED, "1");
          Navigator.pop(context);
        },
        child: Container(
          padding: getEdgeInsets(1, 1),
          margin: EdgeInsets.only(bottom: 8),
          decoration: getBoxDecoration(1, 1),
          child: getTextLabel("< Go back", 1, 1, context),
        ));
  }
}
