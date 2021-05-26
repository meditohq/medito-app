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
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SessionOptionsScreen extends StatefulWidget {
  final String id;
  final Screen screenKey;

  SessionOptionsScreen({Key key, this.id, this.screenKey}) : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {
  //todo move this to the _bloc
  bool showIndeterminateSpinner = false;

  BuildContext scaffoldContext;
  SessionOptionsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = SessionOptionsBloc(widget.id, widget.screenKey);
    _bloc.fetchOptions(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: _bloc.primaryColourController.stream,
        builder: (context, snapshot) {
          return RefreshIndicator(
              onRefresh: () => _bloc.fetchOptions(widget.id, skipCache: true),
              child: Scaffold(
                body: Builder(builder: (BuildContext context) {
                  scaffoldContext = context;
                  return SingleChildScrollView(
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _getHeaderWidget(),
                            _getContentListWidget()
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ));
        });
  }

  HeaderWidget _getHeaderWidget() => HeaderWidget(
      primaryColorController: _bloc.primaryColourController,
      titleController: _bloc.titleController,
      coverController: _bloc.imageController,
      backgroundImageController: _bloc.backgroundImageController,
      descriptionController: _bloc.descController,
      vertical: true);

  Future<void> _onBeginTap(AudioFile item) {
    if (_bloc.isDownloading(item) || showIndeterminateSpinner) return null;

    _bloc.saveOptionsSelectionsToSharedPreferences(widget.id);

    _bloc.startAudioService(item);

    NavigationFactory.navigate(context, Screen.player, id: widget.id);

    return null;
  }

  Widget _getContentListWidget() {
    return StreamBuilder<ApiResponse<List<ExpandableItem>>>(
        stream: _bloc.contentListController.stream,
        initialData: ApiResponse.loading(),
        builder: (context, itemsSnapshot) {
          if (itemsSnapshot.data.status == Status.LOADING) {
            return _getLoadingWidget();
          }
          return _buildPanel(itemsSnapshot.data.body);
        });
  }

  Padding _getLoadingWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPanel(List<ExpandableItem> items) {
    var childList = <Theme>[];

    items.forEach((value) {
      var tileList = value.expandedValue
          .map<ListTile>((e) => _getListItem(context, e))
          .toList();

      childList.add(Theme(
        data: Theme.of(context)
            .copyWith(unselectedWidgetColor: MeditoColors.walterWhite),
        child: ExpansionTile(
            backgroundColor: MeditoColors.darkMoon,
            collapsedBackgroundColor: MeditoColors.intoTheNight,
            maintainState: true,
            title: _getVoiceText(value.headerValue),
            initiallyExpanded: value.isExpanded,
            children: tileList),
      ));
    });

    return Column(
      children: childList,
    );
  }

  Widget _getVoiceText(String voice) => Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
            child: Column(
              children: [
                Text(voice, style: Theme.of(context).textTheme.headline1),
              ],
            ),
          ),
        ],
      );

  Widget _getListItem(BuildContext context, AudioFile item) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 4),
      title: Text('-  ${formatSessionLength(item.length)}',
          style: Theme.of(context).textTheme.headline4),
      onTap: () => _onBeginTap(item),
      enableFeedback: true,
      minVerticalPadding: 1,
      trailing: _getTrailing(item),
    );
  }

  Widget _getTrailing(AudioFile item) {
    if (_bloc.isDownloading(item)) {
      return IconButton(onPressed: () {}, icon: _getLoadingSpinner(item));
    }

    return FutureBuilder<bool>(
        future: DownloadsBloc.isAudioFileDownloaded(item),
        initialData: false,
        builder: (context, snapshot) {
          return IconButton(
            icon: Icon(
              snapshot.hasData && snapshot.data
                  ? _getDownloadedIcon()
                  : Icons.download_outlined,
              color: MeditoColors.meditoTextGrey,
            ),
            onPressed: () => _download(snapshot.hasData && snapshot.data, item),
          );
        });
  }

  IconData _getDownloadedIcon() => Icons.file_download_done;

  Widget _getLoadingSpinner(AudioFile item) {
    return ValueListenableBuilder(
        valueListenable: _bloc.downloadSingleton.returnNotifier(),
        builder: (context, value, widget) {
          if (value >= 1) {
            return GestureDetector(
                onTap: () => _download(true, item),
                child: Icon(_getDownloadedIcon(),
                    color: MeditoColors.walterWhite));
          } else {
            print('Updated value: ' + value.toString());
            return SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                  backgroundColor: Colors.black,
                  value: value,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(MeditoColors.walterWhite)),
            );
          }
        });
  }

  void _download(bool downloaded, AudioFile file) {
    var mediaItem = _bloc.getMediaItemForAudioFile(file);

    if (downloaded) {
      DownloadsBloc.removeSessionFromDownloads(context, mediaItem).then((value) {
        setState(() {

        });
      });
    } else {
      _bloc.setFileForDownloadSingleton(file);
      _bloc.downloadSingleton.start(context, file, mediaItem);
      setState(() {});
    }
  }
}
