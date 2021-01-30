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

import 'package:Medito/audioplayer/player_button.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/sessionoptions/session_options_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../audioplayer/player_utils.dart';
import '../../utils/colors.dart';

class SessionOptionsScreen extends StatefulWidget {
  final String id;

  SessionOptionsScreen({Key key, this.id}) : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {
  var _primaryColor;
  String _secondaryColor;

  bool showIndeterminateSpinner = false;

  /// deffo need:
  BuildContext scaffoldContext;
  SessionOptionsBloc _bloc;

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.SESSION_TAPPED);

    _bloc = SessionOptionsBloc(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Semantics(
        label: 'Play button',
        child: PlayerButton(
          onPressed: _onBeginTap,
          child:
              SizedBox(width: 24, height: 24, child: getBeginButtonContent()),
          primaryColor: _primaryColor != null
              ? parseColor(_primaryColor)
              : MeditoColors.walterWhite,
        ),
      ),
      body: Builder(builder: (BuildContext context) {
        scaffoldContext = context;
        return Container(
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                SingleChildScrollView(
                  child: Stack(
                    children: [
                      GradientWidget(
                        height: 250.0,
                        primaryColor: parseColor(_primaryColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          MeditoAppBarWidget(title: '', transparent: true),
                          buildImage(),
                          buildTitleText(),
                          buildDescriptionText(),
                          buildSpacer(),
                          buildTextHeaderForRow('Voice'),
                          buildVoiceRow(),
                          buildSpacer(),
                          ////////// spacer
                          buildTextHeaderForRow('Session length'),
                          buildSessionLengthRow(),
                          getBGMusicSpacer(),
                          ////////// spacer
                          getBGMusicRowOrContainer(),
                          buildBackgroundMusicRow(),
                          buildSpacer(),
                          ////////// spacer
                          buildTextHeaderForRow(
                              'Available Offline ${_bloc.availableOfflineIndicatorText}'),
                          buildOfflineRow(),
                          Container(height: 80)
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget getBGMusicRowOrContainer() => _bloc.backgroundMusicAvailable
      ? buildTextHeaderForRow('Background Sounds')
      : Container();

  Widget getBGMusicSpacer() =>
      _bloc.backgroundMusicAvailable ? buildSpacer() : Container();

  Widget getBeginButtonContent() {
    _bloc.setCurrentFileForDownloadSingleton();

    if (_bloc.isDownloading()) {
      return ValueListenableBuilder(
          valueListenable: _bloc.downloadSingleton.returnNotifier(),
          builder: (context, value, widget) {
            if (value >= 1) {
              return Icon(Icons.play_arrow, color: parseColor(_secondaryColor));
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
                          parseColor(_secondaryColor),
                        ),
                      ),
                    ],
                  ));
            }
          });
    } else if (showIndeterminateSpinner || _bloc.removing) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(parseColor(_secondaryColor))),
      );
    } else {
      return Icon(Icons.play_arrow, color: parseColor(_secondaryColor));
    }
  }

  Future<void> _onBeginTap() {
    Tracking.trackEvent(Tracking.TAP, Tracking.PLAY_TAPPED, widget.id);

    _bloc.setCurrentFileForDownloadSingleton(); //fixme can i remove this line?
    _bloc.saveOptionsSelectionsToSharedPreferences(widget.id);

    if (_bloc.isDownloading() || showIndeterminateSpinner) return null;

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

  Widget buildTitleText() {
    return StreamBuilder<ApiResponse<String>>(
        stream: _bloc.titleController.stream,
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
            child: Text(
              snapshot.data?.body ?? '',
              style: Theme.of(context).textTheme.bodyText1,
            ),
          );
        });
  }

  Widget buildDescriptionText() {
    return StreamBuilder<ApiResponse<String>>(
        stream: _bloc.descController.stream,
        builder: (context, snapshot) {
          return (snapshot.data?.body?.isNotEmpty ?? false)
              ? Padding(
                  padding:
                      const EdgeInsets.only(bottom: 20.0, left: 16, right: 16),
                  child: Html(data: snapshot.data?.body))
              : Container();
        });
  }

  Widget buildTextHeaderForRow(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headline3.copyWith(
            color: MeditoColors.walterWhite.withOpacity(0.7),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3),
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
                    label:
                        Text(snapshot.data?.body[index]),
                    selected: _bloc.lengthSelected == index,
                    onSelected: (bool value) {
                      onSessionPillTap(value, index);
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

  Widget buildVoiceRow() {
    return SizedBox(
      height: 56,
      child: StreamBuilder<ApiResponse<List<String>>>(
          stream: _bloc.voiceListController.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data?.status == Status.LOADING) {
              return _getEmptyPillRow();
            }

            return ListView.builder(
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
            );
          }),
    );
  }

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

  Future<void> onVoicePillTap(bool value, int index) async {
    _bloc.voiceSelected = index;

    await _bloc.setCurrentFile();

    if (mounted) {
      setState(() {
        _bloc.filterLengthsForVoice(voiceIndex: index);
        _updateAvailableOfflineIndicatorText();
      });
    }
  }

  Future<void> onSessionPillTap(bool value, int index) async {
    // filesList.forEach((file) => {
    //       if (file.length == (_bloc.lengthList[index]) &&
    //           file.voice == (_bloc.voiceList[_bloc.voiceSelected]))
    //         currentFile = file
    //     });
    // _bloc.offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    // setState(() {
    //   _bloc.lengthSelected = index;
    //   _updateAvailableOfflineIndicatorText();
    // });
  }

  TextStyle getLengthPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _bloc.lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getOfflinePillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _bloc.offlineSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getMusicPillTextStyle(int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _bloc.musicSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _bloc.voiceSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
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

  Widget buildBackgroundMusicRow() {
    if (!_bloc.backgroundMusicAvailable) return Container();

    if (_bloc.bgMusicList.isEmpty) return _getEmptyPillRow();

    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.only(left: 16),
          shrinkWrap: true,
          itemCount: 1 + (_bloc.bgMusicList.length ?? 0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: buildInBetweenChipPadding(index),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                labelPadding: buildInnerChipPadding(),
                showCheckmark: false,
                label: Text(
                    index == 0 ? 'None' : _bloc.bgMusicList[index - 1].key),
                selected: index == _bloc.musicSelected,
                onSelected: (bool value) {
                  onMusicSelected(
                      index,
                      index > 0 ? _bloc.bgMusicList[index - 1].value : '',
                      index > 0 ? _bloc.bgMusicList[index - 1].key : '');
                },
                backgroundColor: MeditoColors.moonlight,
                selectedColor: MeditoColors.walterWhite,
                labelStyle: getMusicPillTextStyle(index),
              ),
            );
          },
        ));
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

  void onMusicSelected(int index, String url, String name) {
    _bloc.musicSelected = index;
    print('bg selected: $name');
    if (index > 0) {
      showIndeterminateSpinner = true;
      downloadBGMusicFromURL(url, name).then((value) {
        showIndeterminateSpinner = false;
        _bloc.backgroundMusicUrl = value;
        setState(() {});
      }).catchError((onError) {
        print(onError);
        showIndeterminateSpinner = false;
        _bloc.musicSelected = 0;
        _bloc.backgroundMusicUrl = null;
      });
    } else {
      showIndeterminateSpinner = false;
      _bloc.musicSelected = 0;
      _bloc.backgroundMusicUrl = null;
    }
    setState(() {});
  }

  void onOfflineSelected(int index) {
    _bloc.offlineSelected = index;

    _updateAvailableOfflineIndicatorText();
    _bloc.setCurrentFileForDownloadSingleton();

    if (index == 1) {
      // 'YES' selected
      if (_bloc.downloadSingleton.isDownloadingSomething()) {
        _bloc.downloadSingleton.start(_bloc.currentFile);
      } else {
        _bloc.offlineSelected = 0;
        createSnackBarWithColor('Another Download in Progress', scaffoldContext,
            MeditoColors.peacefulBlue);
      }
    } else {
      // 'NO' selected
      _bloc.removeFile(_bloc.currentFile).then((onValue) {
        print('Removed file');
        _bloc.removing = false;
        setState(() {});
      }).catchError((onError) {
        print(onError);
        _bloc.offlineSelected = 0;
        setState(() {});
      });
    }
    setState(() {});
  }

  void _updateAvailableOfflineIndicatorText() {
    if (_bloc.offlineSelected != 0) {
      var time =
          clockTimeToDuration(_bloc.lengthList[_bloc.lengthSelected]).inMinutes;
      _bloc.availableOfflineIndicatorText =
          '(${_bloc.voiceList[_bloc.voiceSelected]} - $time min)';
    } else {
      _bloc.availableOfflineIndicatorText = '';
    }
  }

  Widget buildImage() {
    return StreamBuilder<ApiResponse<String>>(
        stream: _bloc.imageController.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.status == Status.LOADING) {
            return _getEmptyPillRow();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
            child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  color: _primaryColor != null
                      ? parseColor(_primaryColor)
                      : MeditoColors.moonlight,
                ),
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: snapshot.data?.body != null
                        ? Image.network(snapshot.data?.body)
                        : Container() //getNetworkImageWidget(snapshot.data?.body, startHeight: 100),
                    )),
          );
        });
  }

  Widget buildSpacer() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16.0, left: 16, right: 16),
      child: Row(
        children: <Widget>[
          Expanded(child: Container(color: MeditoColors.moonlight, height: 1)),
        ],
      ),
    );
  }
}
