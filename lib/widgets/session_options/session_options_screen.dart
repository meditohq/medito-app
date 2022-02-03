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

import 'dart:ui';

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/session_options/session_options_bloc.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
                body: Stack(children: [
                  SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _getHeaderWidget(),
                        _getContentListWidget(),
                        _bloc.getCurrentlySelectedFile() != null
                            ? DownloadPanelWidget(
                                item: _bloc.getCurrentlySelectedFile(),
                                bloc: _bloc)
                            : Container(),
                        Container(
                          height: 68,
                        )
                      ],
                    ),
                  ),
                  _getBeginButton(snapshot.data),
                ]),
              ));
        });
  }

  Align _getBeginButton(String primaryColor) {
    return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black,
                Colors.transparent,
              ],
            )),
            child: Row(children: [
              Expanded(
                child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
                    child: TextButton(
                      style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                          backgroundColor: parseColor(primaryColor),
                          padding: const EdgeInsets.all(16.0)),
                      onPressed: _onBeginTap,
                      child: StreamBuilder<String>(
                          stream: _bloc.secondaryColorController.stream,
                          builder: (context, snapshot) {
                            return Text(BEGIN,
                                style: Theme.of(context)
                                    .textTheme
                                    .subtitle2
                                    .copyWith(
                                        color: parseColor(snapshot.data)));
                          }),
                    )),
              )
            ])));
  }

  HeaderWidget _getHeaderWidget() => HeaderWidget(
      primaryColorController: _bloc.primaryColourController,
      titleController: _bloc.titleController,
      coverController: _bloc.imageController,
      backgroundImageController: _bloc.backgroundImageController,
      descriptionController: _bloc.descController,
      whiteText: true);

  Future<void> _onBeginTap() {
    var item = _bloc.getCurrentlySelectedFile();
    if (_bloc.isDownloading(item) || showIndeterminateSpinner) return null;

    _bloc.saveOptionsSelectionsToSharedPreferences(widget.id);

    _bloc.startAudioService(item);

    NavigationFactory.navigate(context, Screen.player, id: widget.id);

    return null;
  }

  Widget _getContentListWidget() {
    return StreamBuilder<ApiResponse<List<VoiceItem>>>(
        stream: _bloc.contentListController.stream,
        initialData: ApiResponse.loading(),
        builder: (context, itemsSnapshot) {
          if (itemsSnapshot.data.status == Status.LOADING) {
            return _getLoadingWidget();
          }
          return _buildOptionsPanel(itemsSnapshot.data.body);
        });
  }

  Padding _getLoadingWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child: Center(
          child: CircularProgressIndicator(
              backgroundColor: Colors.black,
              valueColor:
                  AlwaysStoppedAnimation<Color>(MeditoColors.walterWhite))),
    );
  }

  Widget _buildOptionsPanel(List<VoiceItem> items) {
    var childList = <Widget>[];
    // To check whether any of the VoiceItems contains a narrator
    var containsNarrator =
        items.any((voiceItem) => voiceItem.headerValue.isNotEmptyAndNotNull());

    items.forEach((value) {
      var section = _getListItem(context, value);
      childList.add(section);
    });

    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Container(
            decoration: BoxDecoration(
                color: MeditoColors.deepNight,
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 20),
                  Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text(
                          containsNarrator
                              ? PICK_NARRATOR_AND_DURATION.toUpperCase()
                              : PICK_DURATION.toUpperCase(),
                          style: Theme.of(context).textTheme.bodyText1.copyWith(
                              color: MeditoColors.meditoTextGrey,
                              fontWeight: FontWeight.w600))),
                  Container(height: 12),
                  Column(children: childList),
                ])));
  }

  Widget _getListItem(BuildContext context, VoiceItem item) {
    return Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getVoiceTextWidget(item),
              Container(height: 8),
              SingleChildScrollView(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: item.listForVoice
                          .map<Widget>((e) => _getVoiceChipWithPadding(
                              e,
                              _bloc.getAudioList().indexOf(_bloc
                                  .getAudioList()
                                  .firstWhere(
                                      (element) => element.id == e.id))))
                          .toList()))
            ]));
  }

  Widget _getVoiceChipWithPadding(AudioFile e, int index) => Row(children: [
        ChoiceChip(
          selected: _bloc.currentSelectedFileIndex == index,
          onSelected: (bool selected) {
            setState(() {
              _bloc.currentSelectedFileIndex = index;
              _bloc.saveOptionsSelectionsToSharedPreferences(super.widget.id);
            });
          },
          selectedColor: MeditoColors.walterWhite,
          label: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              formatSessionLength(e.length),
              style: Theme.of(context).textTheme.subtitle2.copyWith(
                  color: _bloc.currentSelectedFileIndex == index
                      ? MeditoColors.intoTheNight
                      : MeditoColors.walterWhite),
            ),
          ),
          backgroundColor: MeditoColors.softGrey,
        ),
        Container(width: 8)
      ]);

  Widget _getVoiceTextWidget(VoiceItem item) => item.headerValue.isEmptyOrNull()
      ? Container()
      : Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            '${item.headerValue}',
            style: Theme.of(context).textTheme.headline4,
          ));
}

class DownloadPanelWidget extends StatefulWidget {
  const DownloadPanelWidget({Key key, this.item, this.bloc}) : super(key: key);

  final bloc;
  final AudioFile item;

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
                    style: Theme.of(context).textTheme.bodyText1.copyWith(
                        color: MeditoColors.meditoTextGrey,
                        fontWeight: FontWeight.w600)),
                Container(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_getDownloadLabel(),
                        style: Theme.of(context).textTheme.bodyText1),
                    _getTrailing()
                  ],
                )
              ],
            )),
      ),
    );
  }

  String _getDownloadLabel() {
    if (widget.item.voice.isNotEmptyAndNotNull()) {
      return '${widget.item.voice} — ${formatSessionLength(widget.item.length)}';
    } else {
      return formatSessionLength(widget.item.length);
    }
  }

  Widget _getTrailing() {
    if (widget.bloc.isDownloading(widget.item)) {
      return IconButton(onPressed: () {}, icon: _getLoadingSpinner());
    }

    return FutureBuilder<bool>(
        future: DownloadsBloc.isAudioFileDownloaded(widget.item),
        initialData: false,
        builder: (context, snapshot) {
          return IconButton(
            icon: Icon(
              snapshot.hasData && snapshot.data
                  ? _getDownloadedIcon()
                  : Icons.download_for_offline_rounded,
              color: MeditoColors.walterWhite,
            ),
            onPressed: () => _download(snapshot.hasData && snapshot.data),
          );
        });
  }

  Widget _getLoadingSpinner() {
    return ValueListenableBuilder(
        valueListenable: widget.bloc.downloadSingleton.returnNotifier(),
        builder: (context, value, widget) {
          if (value >= 1) {
            return GestureDetector(
                onTap: () => _download(true),
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

  IconData _getDownloadedIcon() => Icons.highlight_off;

  void _download(
    bool downloaded,
  ) {
    var mediaItem = widget.bloc.getMediaItemForAudioFile(widget.item);

    if (downloaded) {
      DownloadsBloc.removeSessionFromDownloads(context, mediaItem)
          .then((value) {
        setState(() {});
      });
    } else {
      widget.bloc.setFileForDownloadSingleton(widget.item);
      widget.bloc.downloadSingleton.start(context, widget.item, mediaItem);
      setState(() {});
    }
  }
}
