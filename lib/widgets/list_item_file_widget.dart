import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../utils/colors.dart';
import '../viewmodel/list_item.dart';

class ListItemWidget extends StatefulWidget {
  ListItemWidget({Key key, this.item, this.currentlyPlayingState})
      : super(key: key);

  final ListItem item;
  final currentlyPlayingState;

  @override
  _ListItemWidgetState createState() => _ListItemWidgetState();
}

class _ListItemWidgetState extends State<ListItemWidget> {
  Color getBackgroundColor() {
//    if (widget.currentlyPlayingState != null) {
//      return MeditoColors.darkColor;
//    } else
//      return null;
  }

  Widget getListItemImage() {
    return widget.currentlyPlayingState != null
        ? InkWell(
            child: _getPlayPauseIcon(),
            onTap: _playOrPause,
          )
        : getIcon();
  }

  Padding buildFolderIcon() {
    return Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: Icon(Icons.folder, color: MeditoColors.lightColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      color: getBackgroundColor(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Container(
              padding: EdgeInsets.only(top: 2), child: getListItemImage()),
          getTwoTextViewsInColumn(context)
        ],
      ),
    );
  }

  Widget getTwoTextViewsInColumn(BuildContext context) {
    return Flexible(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.item.title, style: Theme.of(context).textTheme.title),
            widget.item.description == null || widget.item.description.isEmpty
                ? Container()
                : Text(
                    widget.item.description,
                    style: Theme.of(context).textTheme.subhead,
                  )
          ]),
    );
  }

  Widget _getPlayPauseIcon() {
//    var iconWidget;
//    var state = widget.currentlyPlayingState;
//    if (state == AudioPlayerState.PLAYING) {
//      iconWidget = Icon(Icons.pause, color: MeditoColors.lightColor);
//    } else if (state == AudioPlayerState.PAUSED ||
//        state == AudioPlayerState.STOPPED ||
//        state == AudioPlayerState.COMPLETED) {
//      iconWidget = Icon(Icons.play_arrow, color: MeditoColors.lightColor);
//    }
//    return Padding(
//      child: iconWidget,
//      padding: EdgeInsets.only(right: 8),
//    );
  }

  Widget getIcon() {
    if (widget.item.type == ListItemType.folder) {
      return buildFolderIcon();
    }

    var iconWidget;
    var path;

    switch (widget.item.fileType) {
      case FileType.audio:
        iconWidget = Icon(
          Icons.headset,
          color: MeditoColors.lightColor,
        );
        break;
      case FileType.both:
        iconWidget = Icon(
          Icons.headset,
          color: MeditoColors.lightColor,
        );
        break;
      case FileType.text:
        path = 'assets/images/ic_document.svg';
        iconWidget = SvgPicture.asset(
          path,
          color: MeditoColors.lightColor,
        );
        break;
    }

    return Padding(padding: EdgeInsets.only(right: 8), child: iconWidget);
  }

  void _playOrPause() {
//    setState(() {
//      var state = widget.currentlyPlayingState;
//      if (state == AudioPlayerState.PLAYING) {
//        Tracking.trackEvent(
//            Tracking.FILE_TAPPED, Tracking.AUDIO_PLAY, widget.item.id);
//        MeditoAudioPlayer().audioPlayer.pause();
//      } else if (state == AudioPlayerState.PAUSED) {
//        Tracking.trackEvent(
//            Tracking.FILE_TAPPED, Tracking.AUDIO_RESUME, widget.item.id);
//        MeditoAudioPlayer().audioPlayer.resume();
//      } else if (state == AudioPlayerState.STOPPED ||
//          state == AudioPlayerState.COMPLETED) {
//        Tracking.trackEvent(
//            Tracking.FILE_TAPPED, Tracking.AUDIO_PLAY, widget.item.id);
//        MeditoAudioPlayer().audioPlayer.play(widget.item.url);
//      }
//    });
  }
}
