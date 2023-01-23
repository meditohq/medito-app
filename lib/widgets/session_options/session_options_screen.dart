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

import 'package:Medito/utils/navigation_extra.dart';
import 'package:Medito/widgets/session_options/session_buttons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

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
