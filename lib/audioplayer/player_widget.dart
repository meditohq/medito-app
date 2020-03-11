import 'package:Medito/tracking/tracking.dart';
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
  static double widthOfScreen = 1;


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
//    MeditoAudioPlayer().audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widthOfScreen = MediaQuery.of(context).size.width;

    return Container(
      color: MeditoColors.darkColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(height: 1, color: MeditoColors.lightColorLine),
          _buildMarquee(),
          widget.showReadMoreButton ? _buildReadMoreButton() : Container(),
          buildControlRow(),
          buildSeekBar()
        ],
      ),
    );
  }

  Widget buildSeekBar() {
    return Stack(
      children: <Widget>[
        Container(
          height: 16,
          color: MeditoColors.lightColorLine,
        ),
        Container(
          width: getSeekWidth(),
          height: 16,
          color: MeditoColors.lightColor,
        )
      ],
    );
  }

  double getSeekWidth() {
    if (position == null || maxDuration == null) return 0;
    if (position.inMilliseconds == 0 || maxDuration.inMilliseconds == 0)
      return 0;

    var width = position.inMilliseconds.toDouble() /
        maxDuration.inMilliseconds.toDouble() *
        widthOfScreen.toDouble();

    return width <= 0 ? 0 : width;
  }

  Widget buildControlRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          FlatButton(
            materialTapTargetSize: MaterialTapTargetSize.padded,
            child: Text('← 15s', style: Theme.of(context).textTheme.display2),
            onPressed: _rewind,
          ),
          FlatButton(child: getPlayOrPauseIcon(), onPressed: _resumeOrPlay),
          FlatButton(
            child: Text('15s →', style: Theme.of(context).textTheme.display2),
            onPressed: _fastForward,
          ),
        ],
      ),
    );
  }

  Icon getPlayOrPauseIcon() {

  }

  Widget _buildMarquee() {
    return Padding(
      padding:
          const EdgeInsets.only(left: 24.0, right: 24.0, top: 16, bottom: 16),
      child: Center(
        child: Text(
          widget.fileModel != null ? widget.fileModel.title : "  ",
          softWrap: false,
          overflow: TextOverflow.fade,
          style: Theme.of(context).textTheme.display3,
        ),
      ),
    );
  }

  void _resumeOrPlay() async {

  }

  void _resume() async {
    Tracking.trackEvent(
        Tracking.PLAYER_TAPPED, Tracking.AUDIO_RESUME, widget.fileModel?.title);
  }

  void _play() async {
    Tracking.trackEvent(
        Tracking.PLAYER_TAPPED, Tracking.AUDIO_PLAY, widget.fileModel?.title);
  }

  void _pause() async {
    Tracking.trackEvent(
        Tracking.PLAYER_TAPPED, Tracking.AUDIO_PAUSED, widget.fileModel?.title);
  }

  void _rewind() async {
    Tracking.trackEvent(
        Tracking.PLAYER_TAPPED, Tracking.AUDIO_REWIND, widget.fileModel?.title);
  }

  void _fastForward() async {
    Tracking.trackEvent(
        Tracking.PLAYER_TAPPED, Tracking.AUDIO_FF, widget.fileModel?.title);
  }

  void _stop() async {
  }

  Widget _buildReadMoreButton() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 1,
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 8.0, left: 24.0, right: 24.0),
            child: OutlineButton(
              child: Text(
                "READ MORE",
                style: Theme.of(context).textTheme.display2,
              ),
              highlightedBorderColor: MeditoColors.lightColor,
              borderSide: BorderSide(color: MeditoColors.lightColor),
              onPressed: widget.readMorePressed,
            ),
          ),
        ),
      ],
    );
  }
}
