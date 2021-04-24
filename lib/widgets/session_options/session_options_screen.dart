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

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/network/session_options/session_options_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/header_widget.dart';
import 'package:Medito/widgets/player/player_button.dart';
import 'package:flutter/material.dart';

class session_optionsScreen extends StatefulWidget {
  final String id;
  final Screen screenKey;

  session_optionsScreen({Key key, this.id, this.screenKey}) : super(key: key);

  @override
  _session_optionsScreenState createState() => _session_optionsScreenState();
}

class _session_optionsScreenState extends State<session_optionsScreen> {
  //todo move this to the _bloc
  bool showIndeterminateSpinner = false;

  /// deffo need:
  BuildContext scaffoldContext;
  SessionOptionsBloc _bloc;

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.SESSION_TAPPED);

    _bloc = SessionOptionsBloc(widget.id, widget.screenKey);
    _bloc.fetchOptions(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: _bloc.primaryColourController.stream,
        builder: (context, snapshot) {
          var iconColor = snapshot.hasData
              ? parseColor(snapshot.data)
              : MeditoColors.darkMoon;

          return RefreshIndicator(
              onRefresh: () => _bloc.fetchOptions(widget.id, skipCache: true),
              child: Scaffold(
                floatingActionButton: _getPlayerButton(iconColor),
                body: Builder(builder: (BuildContext context) {
                  scaffoldContext = context;
                  return SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _getHeaderWidget(),
                            buildVoiceRowWithTitle(),
                            buildSpacer(),
                            ////////// spacer
                            buildTextHeaderForRow(DURATION),
                            buildSessionLengthRow(),
                            buildSpacer(),
                            ////////// spacer
                            getBGMusicItems(),
                            ////////// spacer
                            buildTextHeaderForRow(
                                '$DOWNLOAD_SESSION ${_bloc.availableOfflineIndicatorText}'),
                            buildOfflineRow(),
                            Container(height: 80)
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ));
        });
  }

  HeaderWidget _getHeaderWidget() {
    return HeaderWidget(
        primaryColorController: _bloc.primaryColourController,
        titleController: _bloc.titleController,
        coverController: _bloc.imageController,
        backgroundImageController: _bloc.backgroundImageController,
        descriptionController: _bloc.descController,
        vertical: true);
  }

  Semantics _getPlayerButton(Color iconColor) {
    return Semantics(
      label: 'Play button',
      child: PlayerButton(
        onPressed: _onBeginTap,
        primaryColor: iconColor,
        child: SizedBox(
          width: 24,
          height: 24,
          child: _getBeginButtonContent(),
        ),
      ),
    );
  }

  Widget getBGMusicItems() => StreamBuilder<bool>(
      stream: _bloc.backgroundMusicShownController.stream,
      initialData: true,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTextHeaderForRow(BACKGROUND_SOUND),
              buildBackgroundMusicRowAndSpacer(),
              buildSpacer(),
            ],
          );
        } else {
          return Container();
        }
      });

  Widget _getBeginButtonContent() {
    return StreamBuilder<String>(
        stream: _bloc.secondaryColorController.stream,
        initialData: null,
        builder: (context, snapshot) {
          var iconColor = snapshot.data;

          if (_bloc.isDownloading()) {
            return ValueListenableBuilder(
                valueListenable: _bloc.downloadSingleton.returnNotifier(),
                builder: (context, value, widget) {
                  if (value >= 1) {
                    return Icon(Icons.play_arrow, color: parseColor(iconColor));
                  } else {
                    print('Updated value: ' + (value * 100).toInt().toString());
                    return SizedBox(
                      height: 12,
                      width: 12,
                      child: Stack(
                        children: [
                          CircularProgressIndicator(
                            value: 1,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black12),
                          ),
                          CircularProgressIndicator(
                              value: value,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  parseColor(iconColor))),
                        ],
                      ),
                    );
                  }
                });
          } else if (showIndeterminateSpinner || _bloc.removing) {
            return SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(parseColor(iconColor))),
            );
          } else {
            return Icon(Icons.play_arrow, color: parseColor(iconColor));
          }
        });
  }

  Future<void> _onBeginTap() {
    if (_bloc.isDownloading() || showIndeterminateSpinner) return null;

    Tracking.trackEvent(Tracking.TAP, Tracking.PLAY_TAPPED, widget.id);
    _bloc.saveOptionsSelectionsToSharedPreferences(widget.id);

    _bloc.startAudioService();

    NavigationFactory.navigate(context, Screen.player, id: widget.id);

    //shows a spinner just while the next screen is preparing itself
    setState(() {
      showIndeterminateSpinner = true;
      Future.delayed(const Duration(milliseconds: 3000), () {
        setState(() {
          showIndeterminateSpinner = false;
        });
      });
    });

    return null;
  }

  /// Pill rows
  Widget buildTextHeaderForRow(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.caption,
      ),
    );
  }

  Widget buildSessionLengthRow() {
    return StreamBuilder<ApiResponse<List<String>>>(
        stream: _bloc.lengthListController.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.status == Status.LOADING) {
            return _getEmptyPillRow();
          }

          return SizedBox(
            height: 56,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 16),
              shrinkWrap: true,
              itemCount: snapshot.data.body?.length ?? 0,
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                if (snapshot.data.status == Status.LOADING) {
                  return _getEmptyPillRow();
                }

                return Padding(
                  padding: buildInBetweenChipPadding(index),
                  child: FilterChip(
                    pressElevation: 4,
                    shape: buildChipBorder(),
                    showCheckmark: false,
                    labelPadding: buildInnerChipPadding(),
                    label: Text(snapshot.data?.body[index]),
                    selected: _bloc.lengthSelected == index,
                    onSelected: (bool value) {
                      onSessionLengthPillTap(index);
                    },
                    backgroundColor: MeditoColors.moonlight,
                    selectedColor: MeditoColors.walterWhite,
                    labelStyle: getLengthPillTextStyle(context, index),
                  ),
                );
              },
            ),
          );
        });
  }

  Widget buildOfflineRow() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        shrinkWrap: true,
        itemCount: 2,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: buildInBetweenChipPadding(index),
            child: FilterChip(
              pressElevation: 4,
              shape: buildChipBorder(),
              showCheckmark: false,
              labelPadding: buildInnerChipPadding(),
              label: Text(index == 0 ? 'No' : 'Yes'),
              selected: _bloc.offlineSelected == index,
              onSelected: (bool value) {
                onOfflineSelected(index);
              },
              backgroundColor: MeditoColors.moonlight,
              selectedColor: MeditoColors.walterWhite,
              labelStyle: getOfflinePillTextStyle(context, index),
            ),
          );
        },
      ),
    );
  }

  Widget buildBackgroundMusicRowAndSpacer() {
    return SizedBox(
        height: 56,
        child: StreamBuilder<ApiResponse<BackgroundSoundsResponse>>(
            stream: _bloc.backgroundMusicListController.stream,
            initialData: ApiResponse.loading(),
            builder: (context, snapshot) {
              if (!snapshot.hasData ||
                  snapshot.data?.status == Status.LOADING) {
                return _getEmptyPillRow();
              }

              var data = snapshot.data.body?.data;

              if (data?.isEmpty ?? true) return Container();

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16),
                shrinkWrap: true,
                itemCount: 1 + (data.length ?? 0),
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: buildInBetweenChipPadding(index),
                    child: FilterChip(
                      pressElevation: 4,
                      shape: buildChipBorder(),
                      labelPadding: buildInnerChipPadding(),
                      showCheckmark: false,
                      label: Text(index == 0 ? 'None' : data[index - 1].name),
                      selected: index == _bloc.musicSelected,
                      onSelected: (bool value) {
                        onMusicSelected(
                            index,
                            index > 0 ? data[index - 1].file : '',
                            index > 0 ? data[index - 1].name : '');
                      },
                      backgroundColor: MeditoColors.moonlight,
                      selectedColor: MeditoColors.walterWhite,
                      labelStyle: getMusicPillTextStyle(index),
                    ),
                  );
                },
              );
            }));
  }

  Widget buildVoiceRowWithTitle() {
    return StreamBuilder<ApiResponse<List<String>>>(
        stream: _bloc.voiceListController.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.status == Status.LOADING) {
            return _buildVoiceColumn(_getEmptyPillRow());
          }

          if (snapshot.data.body.isEmpty || snapshot.data.body.first == null) {
            return Container();
          }

          return _buildVoiceColumn(
            ListView.builder(
              padding: const EdgeInsets.only(left: 16),
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.data.body.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: buildInBetweenChipPadding(index),
                  child: FilterChip(
                    shape: buildChipBorder(),
                    labelPadding: buildInnerChipPadding(),
                    label: Text(snapshot.data.body[index]),
                    showCheckmark: false,
                    selected: _bloc.voiceSelected == index,
                    onSelected: (bool value) {
                      onVoicePillTap(value, index);
                    },
                    backgroundColor: MeditoColors.moonlight,
                    selectedColor: MeditoColors.walterWhite,
                    labelStyle: getVoiceTextStyle(context, index),
                  ),
                );
              },
            ),
          );
        });
  }

  Column _buildVoiceColumn(Widget w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 16),
        buildTextHeaderForRow(NARRATOR),
        SizedBox(height: 56, child: w),
      ],
    );
  }

  ///End pill rows

  /// On tap functions
  Future<void> onVoicePillTap(bool value, int index) async {
    _bloc.voiceSelected = index;

    _bloc.filterLengthsForVoice(voiceIndex: index);
    await _bloc.updateCurrentFile();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onSessionLengthPillTap(int index) async {
    _bloc.lengthSelected = index;

    await _bloc.updateCurrentFile();

    if (mounted) {
      setState(() {});
    }
  }

  void onMusicSelected(int index, String id, String name) {
    _bloc.musicSelected = index;
    index > 0 ? _bloc.musicNameSelected = name : _bloc.musicNameSelected = '';
    print('bg selected: $name');
    if (index > 0) {
      showIndeterminateSpinner = true;
      downloadBGMusicFromURL(id, name).then((value) {
        showIndeterminateSpinner = false;
        _bloc.backgroundSoundsId = value;
        setState(() {});
      }).catchError((onError) {
        print(onError);
        showIndeterminateSpinner = false;
        _bloc.musicSelected = 0;
        _bloc.backgroundSoundsId = null;
      });
    } else {
      showIndeterminateSpinner = false;
      _bloc.musicSelected = 0;
      _bloc.backgroundSoundsId = null;
    }
    setState(() {});
  }

  void onOfflineSelected(int index) {
    _bloc.offlineSelected = index;

    if (index == 1) {
      // 'YES' selected
      if (!_bloc.downloadSingleton.isDownloadingSomething()) {
        _bloc.downloadSingleton
            .start(_bloc.currentFile, _bloc.getMediaItemForSelectedFile());
      } else {
        _bloc.offlineSelected = 0;
        createSnackBarWithColor('Another Download in Progress', scaffoldContext,
            MeditoColors.peacefulBlue);
      }
    } else {
      // 'NO' selected
      _bloc.removeFile(_bloc.getMediaItemForSelectedFile()).then((onValue) {
        print('Removed file');
        _bloc.removing = false;
        _bloc.updateCurrentFile();
        setState(() {});
      }).catchError((onError) {
        print(onError);
        _bloc.offlineSelected = 0;
        setState(() {});
      });
    }
    setState(() {});
  }

  /// End on tap functions

  EdgeInsets buildInnerChipPadding() =>
      EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 12);

  EdgeInsets buildInBetweenChipPadding(var index) {
    var leftPadding = index == 0 ? 0.0 : 0.0;
    return EdgeInsets.only(right: 8, left: leftPadding);
  }

  RoundedRectangleBorder buildChipBorder() {
    return RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)));
  }

  TextStyle getLengthPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.subtitle2.copyWith(
        color: _bloc.lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getOfflinePillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.subtitle2.copyWith(
        color: _bloc.offlineSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getMusicPillTextStyle(int index) {
    return Theme.of(context).textTheme.subtitle2.copyWith(
        color: _bloc.musicSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.subtitle2.copyWith(
        color: _bloc.voiceSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  Padding _getEmptyPillRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 4),
      child: Row(
        children: [
          emptyPill(),
          emptyPill(),
        ],
      ),
    );
  }

  Widget emptyPill() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        onSelected: (bool value) {},
        pressElevation: 4,
        shape: buildChipBorder(),
        labelPadding: buildInnerChipPadding(),
        label: Text('        '),
        backgroundColor: MeditoColors.moonlight,
        labelStyle: getLengthPillTextStyle(context, 1),
      ),
    );
  }

  Widget buildSpacer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        color: MeditoColors.deepNight,
        thickness: 1,
      ),
    );
  }
}
