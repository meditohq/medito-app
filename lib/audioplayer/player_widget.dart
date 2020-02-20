import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../viewmodel/list_item.dart';
import 'audio_singleton.dart';

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
  var _lightColor = Color(0xffebe7e4);

  AudioPlayerState state;

  @override
  void initState() {
    super.initState();
    MeditoAudioPlayer()
        .audioPlayer
        .onAudioPositionChanged
        .listen((Duration p) => {
              setState(() {
                return position = p;
              })
            });

    MeditoAudioPlayer().audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() => maxDuration = d);
    });

    MeditoAudioPlayer()
        .audioPlayer
        .onPlayerStateChanged
        .listen((AudioPlayerState s) {
      if (s == AudioPlayerState.COMPLETED || s == AudioPlayerState.STOPPED) {
        maxDuration = Duration(seconds: 0);
        position = Duration(seconds: 0);
      }
      this.state = s;
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widthOfScreen = MediaQuery.of(context).size.width;

    return Container(
      color: Color(0xff343b43),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(height: 1, color: MeditoColors.lightColorTrans),
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
          color: Color(0xff595f65),
        ),
        Container(
          width: getSeekWidth(),
          height: 16,
          color: _lightColor,
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
    return state == AudioPlayerState.PLAYING
        ? Icon(Icons.pause, color: _lightColor, size: 32)
        : Icon(Icons.play_arrow, color: _lightColor, size: 32);
  }

  Widget _buildMarquee() {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16, bottom: 16),
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
    if (state == AudioPlayerState.STOPPED || state == AudioPlayerState.COMPLETED)
      _play();
    else if (state == AudioPlayerState.PAUSED)
      _resume();
    else if (state == AudioPlayerState.PLAYING) _pause();
  }

  void _resume() async {
    await MeditoAudioPlayer().audioPlayer.resume();
  }

  void _play() async {
    await MeditoAudioPlayer().audioPlayer.play(widget.fileModel?.url);
  }

  void _pause() async {
    await MeditoAudioPlayer().audioPlayer.pause();
  }

  void _rewind() async {
    MeditoAudioPlayer()
        .audioPlayer
        .seek(new Duration(seconds: position.inSeconds - 15))
        .then((result) {});
  }

  void _fastForward() async {
    MeditoAudioPlayer()
        .audioPlayer
        .seek(new Duration(seconds: position.inSeconds + 15))
        .then((result) {});
  }

  void _stop() async {
    int result = await MeditoAudioPlayer().audioPlayer.stop();
    MeditoAudioPlayer().audioPlayer.release();
  }

  Widget _buildReadMoreButton() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 24.0, right: 24.0),
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
