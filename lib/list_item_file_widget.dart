import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/audioplayer/audio_singleton.dart';
import 'package:medito/viewmodel/list_item.dart';

class ListItemFileWidget extends StatefulWidget {
  ListItemFileWidget({Key key, this.item, this.currentlyPlayingState})
      : super(key: key);

  final _lightColor = Color(0xffebe7e4);

  final ListItem item;
  final AudioPlayerState currentlyPlayingState;

  @override
  _ListItemFileWidgetState createState() => _ListItemFileWidgetState();
}

class _ListItemFileWidgetState extends State<ListItemFileWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      Flexible(
        child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding:
                      EdgeInsets.only(right: 12.0, left: 4, top: 4, bottom: 4),
                  child: getPlayPauseButton(),
                ),
                Expanded(
                    child: Container(
                        child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                          Text(widget.item.title,
                              style: Theme.of(context).textTheme.title),
                          widget.item.description == null ||
                                  widget.item.description.isEmpty
                              ? Container()
                              : Text(
                                  widget.item.description,
                                  style: Theme.of(context).textTheme.subhead,
                                )
                        ])),
                  ],
                ))),
              ],
            )),
      )
    ]);
  }

  Widget getPlayPauseButton() {
    return widget.currentlyPlayingState != null
        ? GestureDetector(
            child: getPlayPauseIcon(),
            onTap: _playOrPause,
          )
        : getIcon();
  }

  Widget getPlayPauseIcon() {
    if (widget.currentlyPlayingState == AudioPlayerState.PLAYING) {
      return Icon(Icons.pause, color: widget._lightColor);
    } else if (widget.currentlyPlayingState == AudioPlayerState.PAUSED ||
        widget.currentlyPlayingState == AudioPlayerState.STOPPED) {
      return Icon(Icons.play_arrow, color: widget._lightColor);
    }
    return Container();
  }

  Widget getIcon() {
    var path;
    switch (widget.item.fileType) {
      case FileType.audio:
        return Icon(
          Icons.audiotrack,
          color: widget._lightColor,
        );
        break;
      case FileType.text:
        path = 'assets/images/ic_document.svg';
        break;
      case FileType.both:
        path = 'assets/images/ic_audio.svg';
        break;
    }
    return SvgPicture.asset(
      path,
      color: widget._lightColor,
    );
  }

  void _playOrPause() {
    setState(() {
      if (widget.currentlyPlayingState == AudioPlayerState.PLAYING) {
        MeditoAudioPlayer().audioPlayer.pause();
      } else if (widget.currentlyPlayingState == AudioPlayerState.PAUSED ||
          widget.currentlyPlayingState == AudioPlayerState.STOPPED) {
        MeditoAudioPlayer().audioPlayer.play(widget.item.url);
      }
    });
  }
}
