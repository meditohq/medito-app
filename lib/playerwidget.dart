import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class PlayerWidget extends StatefulWidget {
  PlayerWidget({Key key}) : super(key: key);

  @override
  _PlayerWidgetState createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _buildMarquee(),
        ),
        buildControlRow(),
        Container(
          height: 16,
          color: Colors.blue,
        )
      ],
    );
  }

  Row buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        FlatButton(
          materialTapTargetSize: MaterialTapTargetSize.padded,
          child: Icon(Icons.fast_rewind),
          onPressed: () {},
        ),
        FlatButton(
          child: Icon(Icons.pause),
          onPressed: () {},
        ),
        FlatButton(
          child: Icon(Icons.fast_forward),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMarquee() {
    return Marquee(
      blankSpace: 48,
      startPadding: 16,
      crossAxisAlignment: CrossAxisAlignment.center,
      accelerationCurve: Curves.easeInOut,
      text: 'There once was a boy who told this story about a boy.',
    );
  }
}
