/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colors.dart';

class ListItemWidget extends StatefulWidget {
  ListItemWidget({Key key, this.item}) : super(key: key);

  final ListItem item;

  @override
  _ListItemWidgetState createState() => _ListItemWidgetState();
}

class _ListItemWidgetState extends State<ListItemWidget> {
  var currentIcon;

  SharedPreferences prefs;

  Padding buildFolderIcon() {
    return Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: Icon(Icons.folder, color: MeditoColors.lightColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    SharedPreferences.getInstance().then((i) {
      if (this.mounted) {
        setState(() {
          this.prefs = i;
        });
      }
    });

    return Container(
      padding: EdgeInsets.all(16),
      color: MeditoColors.darkBGColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Container(padding: EdgeInsets.only(top: 2), child: getIcon()),
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
            Text(widget.item.title,
                style: Theme.of(context).textTheme.headline6),
            widget.item.description == null || widget.item.description.isEmpty
                ? Container()
                : Text(
                    widget.item.description,
                    style: Theme.of(context).textTheme.subtitle1,
                  )
          ]),
    );
  }

  Widget _getPlayPauseIcon() {
    return Padding(
      child: currentIcon,
      padding: EdgeInsets.only(right: 8),
    );
  }

  Widget getIcon() {
    if (widget.item.type == ListItemType.folder) {
      return buildFolderIcon();
    }

    var iconWidget;
    var path;

    switch (widget.item.fileType) {
      case FileType.audio:
      case FileType.audiosetdaily:
      case FileType.audiosethourly:
        iconWidget = getAudioIcon(iconWidget);
        break;
      case FileType.both:
        iconWidget = getAudioIcon(iconWidget);
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

  Widget getAudioIcon(iconWidget) {
    final listened = prefs?.getBool('listened' + widget.item.id) ?? false;

    if (listened) {
      iconWidget = Icon(
        Icons.check_circle,
        color: MeditoColors.lightColor,
      );
    } else {
      iconWidget = Icon(
        Icons.headset,
        color: MeditoColors.lightColor,
      );
    }
    return iconWidget;
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
