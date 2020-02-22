import 'package:Medito/tracking/tracking.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'audioplayer/audio_singleton.dart';
import 'colors.dart';
import 'viewmodel/list_item.dart';

class ListItemFileWidget extends StatefulWidget {
  ListItemFileWidget({Key key, this.item, this.currentlyPlayingState})
      : super(key: key);

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
              color: getBackgroundColor(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(
                          right: 12.0, left: 4, top: 4, bottom: 4),
                      child: getPlayPauseButton(),
                    ),
                    Expanded(
                        child: Container(
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        style:
                                            Theme.of(context).textTheme.subhead,
                                      )
                              ]))
                        ])))
                  ])))
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
    var state = widget.currentlyPlayingState;
    if (state == AudioPlayerState.PLAYING) {
      return Icon(Icons.pause, color: MeditoColors.lightColor);
    } else if (state == AudioPlayerState.PAUSED ||
        state == AudioPlayerState.STOPPED ||
        state == AudioPlayerState.COMPLETED) {
      return Icon(Icons.play_arrow, color: MeditoColors.lightColor);
    }
    return Container();
  }

  Widget getIcon() {
    var path;
    switch (widget.item.fileType) {
      case FileType.audio:
        return Icon(
          Icons.headset,
          color: MeditoColors.lightColor,
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
      color: MeditoColors.lightColor,
    );
  }

  void _playOrPause() {
    setState(() {
      var state = widget.currentlyPlayingState;
      if (state == AudioPlayerState.PLAYING) {
        Tracking.trackEvent(
            Tracking.FILE_TAPPED, Tracking.AUDIO_PLAY, widget.item.id);
        MeditoAudioPlayer().audioPlayer.pause();
      } else if (state == AudioPlayerState.PAUSED) {
        Tracking.trackEvent(
            Tracking.FILE_TAPPED, Tracking.AUDIO_RESUME, widget.item.id);
        MeditoAudioPlayer().audioPlayer.resume();
      } else if (state == AudioPlayerState.STOPPED ||
          state == AudioPlayerState.COMPLETED) {
        Tracking.trackEvent(
            Tracking.FILE_TAPPED, Tracking.AUDIO_PLAY, widget.item.id);
        MeditoAudioPlayer().audioPlayer.play(widget.item.url);
      }
    });
  }

  Color getBackgroundColor() {
    if (widget.currentlyPlayingState != null) {
      return MeditoColors.darkColor;
    } else
      return null;
  }
}
