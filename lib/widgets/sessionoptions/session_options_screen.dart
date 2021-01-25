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

import 'package:Medito/audioplayer/download_class.dart';
import 'package:Medito/audioplayer/player_button.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/network/sessionoptions/session_options_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:flutter/material.dart';

import '../../audioplayer/player_utils.dart';
import '../../utils/colors.dart';

class SessionOptionsScreen extends StatefulWidget {
  final String id;

  SessionOptionsScreen({Key key, this.id}) : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {
  List<Files> filesList;
  var _primaryColor;
  String _secondaryColor;

  bool showIndeterminateSpinner = false;
  Files currentFile;
  bool _showVoiceChoice = true;

  String _availableOfflineIndicatorText = '';

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
    if (_bloc.voiceList.length == 1 &&
        _bloc.voiceList[0].toString().toLowerCase() == 'no voice') {
      _showVoiceChoice = false;
    }

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
                          _showVoiceChoice ? buildSpacer() : Container(),
                          _showVoiceChoice
                              ? buildTextHeaderForRow('Voice')
                              : Container(),
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
                              'Available Offline $_availableOfflineIndicatorText'),
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
    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(currentFile);
    }
    if (downloadSingleton.isDownloadingMe(currentFile)) {
      return ValueListenableBuilder(
          valueListenable: downloadSingleton.returnNotifier(),
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
    } else if (showIndeterminateSpinner || removing) {
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

    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(currentFile);
    }
    addIntToSF(widget.id, 'voiceSelected', _bloc.voiceSelected);
    addIntToSF(widget.id, 'lengthSelected', _bloc.lengthSelected);
    addIntToSF(widget.id, 'musicSelected', _bloc.musicSelected);

    if (downloadSingleton.isDownloadingMe(currentFile) ||
        showIndeterminateSpinner) return null;

    NavigationFactory.navigate(context, Screen.player, id: widget.id);

    //shows a spinner just while the next scren is preparing itself
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
    //FIXME add streamer
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
      child: Text(
        'widget.title',
        style: Theme.of(context).textTheme.bodyText1,
      ),
    );
  }

  Widget buildDescriptionText() {
    //fixme add streamer
    return ''.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 16, right: 16),
            child: getDescriptionMarkdownBody('', context),
          )
        : Container();
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
    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        shrinkWrap: true,
        itemCount: _bloc.lengthList.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          return Visibility(
            visible:
                _bloc.lengthFilteredList?.contains(_bloc.lengthList[index]),
            child: Padding(
              padding: buildInBetweenChipPadding(index),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                showCheckmark: false,
                labelPadding: buildInnerChipPadding(),
                label: Text(formatSessionLength(index)),
                selected: _bloc.lengthSelected == index,
                onSelected: (bool value) {
                  onSessionPillTap(value, index);
                },
                backgroundColor: MeditoColors.moonlight,
                selectedColor: MeditoColors.walterWhite,
                labelStyle: getLengthPillTextStyle(context, index),
              ),
            ),
          );
        },
      ),
    );
  }

  String formatSessionLength(int index) {
    String lengthText = _bloc.lengthList[index];
    if (lengthText.contains(':')) {
      var duration = clockTimeToDuration(lengthText);
      var time = '';
      if (duration.inMinutes < 1) {
        time = '<1';
      } else {
        time = duration.inMinutes.toString();
      }
      return '$time min';
    }
    return _bloc.lengthList[index] + ' min';
  }

  Widget buildVoiceRow() {
    if (!_showVoiceChoice) {
      return Container();
    }

    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: _bloc.voiceList.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: buildInBetweenChipPadding(index),
            child: FilterChip(
              shape: buildChipBorder(),
              labelPadding: buildInnerChipPadding(),
              label: Text(_bloc.voiceList[index]),
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

    for (final file in filesList) {
      if (file.voice == (_bloc.voiceList[index])) {
        currentFile = file;
        if (downloadSingleton == null || !downloadSingleton.isValid()) {
          downloadSingleton = DownloadSingleton(currentFile);
        }
        break;
      }
    }
    _bloc.offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    if (mounted) {
      setState(() {
        //todo filter lengths for this person
        _updateAvailableOfflineIndicatorText();
      });
    }
  }

  Future<void> onSessionPillTap(bool value, int index) async {
    filesList.forEach((file) => {
          if (file.length == (_bloc.lengthList[index]) &&
              file.voice == (_bloc.voiceList[_bloc.voiceSelected]))
            currentFile = file
        });
    _bloc.offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    setState(() {
      _bloc.lengthSelected = index;
      _updateAvailableOfflineIndicatorText();
    });
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

    if (_bloc.bgMusicList.isEmpty) return getEmptyPillRow();

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

  Padding getEmptyPillRow() {
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

    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(currentFile);
    }
    if (index == 1) {
      // 'YES' selected
      if (!downloadSingleton.isDownloadingSomething()) {
        downloadSingleton.start(currentFile);
      } else {
        _bloc.offlineSelected = 0;
        createSnackBarWithColor('Another Download in Progress', scaffoldContext,
            MeditoColors.peacefulBlue);
      }
    } else {
      // 'NO' selected
      removing = true;
      removeFile(currentFile).then((onValue) {
        setState(() {
          print('Removed file');
          //removing = false;
        });
      }).catchError((onError) {
        setState(() {
          print(onError);
          _bloc.offlineSelected = 0;
        });
      });
    }
    setState(() {});
  }

  void _updateAvailableOfflineIndicatorText() {
    if (_bloc.offlineSelected != 0) {
      var time =
          clockTimeToDuration(_bloc.lengthList[_bloc.lengthSelected]).inMinutes;
      _availableOfflineIndicatorText =
          '(${_bloc.voiceList[_bloc.voiceSelected]} - $time min)';
    } else {
      _availableOfflineIndicatorText = '';
    }
  }

  Widget buildImage() {
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
            child: _bloc.illustration == null
                ? Container()
                : getNetworkImageWidget(_bloc.illustration.url),
          )),
    );
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
