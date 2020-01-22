import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:medito/audioplayer/audiosingleton.dart';
import 'package:medito/viewmodel/filemodel.dart';

class PlayerWidget extends StatefulWidget {

  PlayerWidget({Key key, this.fileModel}) : super(key: key);
  final FileModel fileModel;

  @override
  _PlayerWidgetState createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  bool _playing = false;
  static Duration position;
  static Duration maxDuration;
  static double widthOfScreen = 1;

  @override
  void initState() {
    super.initState();
    MeditoAudioPlayer()
        .audioPlayer
        .onAudioPositionChanged
        .listen((Duration p) => {setState(() => position = p)});

    MeditoAudioPlayer().audioPlayer.onDurationChanged.listen((Duration d) {
      print('Max duration: $d');
      setState(() => maxDuration = d);
    });

    MeditoAudioPlayer()
        .audioPlayer
        .onPlayerStateChanged
        .listen((AudioPlayerState s) {
      if (s == AudioPlayerState.PAUSED) {
        setState(() {
          _playing = false;
        });
      }

      if (s == AudioPlayerState.COMPLETED ||
          s == AudioPlayerState.STOPPED) {
        setState(() {
          _playing = false;
          maxDuration = Duration(seconds: 0);
          position = Duration(seconds: 0);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widthOfScreen = MediaQuery.of(context).size.width;

    return Column(
      children: <Widget>[
        Expanded(child: _buildMarquee()),
        buildControlRow(),
        buildSeekBar()
      ],
    );
  }

  Widget buildSeekBar() {
    return Stack(
      children: <Widget>[
        Container(
          height: 16,
          color: Colors.blue,
        ),
        Container(
          width: getSeekWidth(),
          height: 16,
          color: Colors.black,
        )
      ],
    );
  }

  double getSeekWidth() {
    if (position == null || maxDuration == null) return 0;
    if (position.inMilliseconds == 0 || maxDuration.inMilliseconds == 0) return 0;

    var width = position.inMilliseconds.toDouble() /
        maxDuration.inMilliseconds.toDouble() *
        widthOfScreen.toDouble();

    return width <= 0 ? 0 : width;

  }

  Row buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        FlatButton(
          materialTapTargetSize: MaterialTapTargetSize.padded,
          child: Icon(Icons.fast_rewind),
          onPressed: _rewind,
        ),
        FlatButton(
          child: _playing ? Icon(Icons.pause) : Icon(Icons.play_arrow),
          onPressed: _playing ? _pause : _play,
        ),
        FlatButton(
          child: Icon(Icons.fast_forward),
          onPressed: _fastForward,
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
      text: widget.fileModel != null ? widget.fileModel.fileName : " ",
    );
  }

  void _play() async {
    int result =
        await MeditoAudioPlayer().audioPlayer.play(widget.fileModel.fileUrl);
    if (result == 1) {
      setState(() {
        _playing = true;
      });
    }
  }

  void _pause() async {
    int result = await MeditoAudioPlayer().audioPlayer.pause();
    if (result == 1) {}
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
}
