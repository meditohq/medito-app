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

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/session_options/session_options_bloc.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/session_options/session_buttons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../audioplayer/audio_inherited_widget.dart';
import '../medito_header_widget.dart';

class SessionOptionsScreen extends StatefulWidget {
  final String? id;
  final Screen? screenKey;

  SessionOptionsScreen({Key? key, this.id, this.screenKey}) : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {

  late AudioHandler? _audioHandler;

  @override
  Widget build(BuildContext context) {
    _audioHandler = AudioHandlerInheritedWidget.of(context).audioHandler;

    return content();
  }

  RefreshIndicator content() {
    return RefreshIndicator(
        onRefresh: () => _refresh(),
        child: Scaffold(
          body: Stack(children: [
            SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _getHeaderWidget(),
                  _getBodyWidget(),
                  DownloadPanelWidget(),
                ],
              ),
            ),
          ]),
        ));
  }

  HeaderWidget _getHeaderWidget() =>
      HeaderWidget('Title', 'Long description!!', '');

  Future<void> _onBeginTap() {
    // var item = _bloc.getCurrentlySelectedFile();
    // if (_bloc.isDownloading(item) || showIndeterminateSpinner) {
    //   return Future.value(null);
    // }
    //
    // if (widget.id != null) {
    //   _bloc.saveOptionsSelectionsToSharedPreferences(widget.id!);
    // }
    //
    // var mediaItem = _bloc.getMediaItem(item);
    // _audioHandler?.playMediaItem(mediaItem);
    // context.go(GoRouter.of(context).location + PlayerPath);
    return Future.value(null);
  }

  Widget _getBodyWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24),
          Text('Select a guide and a duration'),
          SessionButtons()
        ],
      ),
    );
  }

  _refresh() {}
}

class DownloadPanelWidget extends StatefulWidget {
  const DownloadPanelWidget({Key? key}) : super(key: key);

  @override
  _DownloadPanelWidgetState createState() => _DownloadPanelWidgetState();
}

class _DownloadPanelWidgetState extends State<DownloadPanelWidget> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: MeditoColors.deepNight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
            padding: EdgeInsets.only(top: 20, bottom: 16, left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DOWNLOAD.toUpperCase(),
                    style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        color: MeditoColors.meditoTextGrey,
                        fontWeight: FontWeight.w600)),
                Container(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Text(_getDownloadLabel(),
                    //     style: Theme.of(context).textTheme.bodyText1),
                    // _getTrailing()
                  ],
                )
              ],
            )),
      ),
    );
  }

/* return FutureBuilder<bool>(
        future: DownloadsBloc.isAudioFileDownloaded(widget.item),
        initialData: false,
        builder: (context, snapshot) {
          return IconButton(
            icon: Icon(
              snapshot.hasData && snapshot.data == true
                  ? _getDownloadedIcon()
                  : Icons.download_for_offline_rounded,
              color: MeditoColors.walterWhite,
            ),
            onPressed: () =>
                _download(snapshot.hasData && snapshot.data == true),
          );
        });*/
// }

// void _download(
//   bool downloaded,
// ) {
//   var mediaItem = widget.bloc.getMediaItemForAudioFile(widget.item);
//
//   if (downloaded) {
//     DownloadsBloc.removeSessionFromDownloads(context, mediaItem)
//         .then((value) {
//       setState(() {});
//     });
//   } else {
//     widget.bloc.setFileForDownloadSingleton(widget.item);
//     widget.bloc.downloadSingleton.start(context, widget.item, mediaItem);
//     setState(() {});
//   }
// }
}
