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

import 'dart:io';

import 'package:Medito/audioplayer/download_class.dart';
import 'package:Medito/audioplayer/player_button.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/bottom_sheet_view_model.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:flutter/material.dart';

import '../audioplayer/player_utils.dart';
import '../utils/colors.dart';

class SessionOptionsScreen extends StatefulWidget {
  final Future data;
  final String title;
  final String id;
  final Function(Files, Illustration, dynamic, String, String, String, String,
      String, int) onBeginPressed;

  SessionOptionsScreen(
      {Key key, this.title, this.data, this.onBeginPressed, this.id})
      : super(key: key);

  @override
  _SessionOptionsScreenState createState() => _SessionOptionsScreenState();
}

class _SessionOptionsScreenState extends State<SessionOptionsScreen> {
  var voiceSelected = 0;
  var lengthSelected = 0;
  var _offlineSelected = 0;
  var _musicSelected = 0;
  List voiceList = [' ', ' ', ' '];
  List lengthList = [' ', ' ', ' '];
  List lengthFilteredList = [];
  List<Files> filesList;
  var _illustration;
  String _description;
  String _title;
  var _primaryColor;
  String _secondaryColor;
  String _contentText = '';

  bool showIndeterminateSpinner = false;
  Files currentFile;
  var _backgroundMusicUrl;
  var _backgroundMusicAvailable = false;
  bool _showVoiceChoice = true;

  String _availableOfflineIndicatorText = "";

  bool _loadingThisPage = true;
  final _viewModel = new BottomSheetViewModelImpl();

  List _bgMusicList = [];

  BuildContext scaffoldContext;

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.SESSION_TAPPED);

    getIntValuesSF(widget.id, 'voiceSelected')
        .then((value) => voiceSelected = value);
    getIntValuesSF(widget.id, 'lengthSelected')
        .then((value) => lengthSelected = value);
    getIntValuesSF(widget.id, 'musicSelected')
        .then((value) => _musicSelected = value);
    _viewModel.getBackgroundMusicList().then((value) {
      setState(() {
        _bgMusicList = value;
      });
    });

    widget.data.then((d) {
      this._illustration =
          d?.illustration != null ? d?.illustration?.first : null;
      this._primaryColor = d?.primaryColor;
      this._title = d?.title;
      this._secondaryColor = d?.secondaryColor;
      this._contentText = d?.description;
      this._description = d?.subtitle;
      compileLists(d?.files);
      onVoicePillTap(true, 0);
      setState(() {
        _loadingThisPage = false;
        this._backgroundMusicAvailable = d?.backgroundMusic;
      });
    }).catchError(_onFirstFutureError);
  }

  @override
  Widget build(BuildContext context) {
    if (voiceList.length == 1 &&
        voiceList[0].toString().toLowerCase() == 'no voice') {
      _showVoiceChoice = false;
    }

    return Scaffold(
      floatingActionButton: Semantics(
        label: "Play button",
        child: PlayerButton(
          onPressed: _onBeginTap,
          child:
              SizedBox(width: 24, height: 24, child: getBeginButtonContent()),
          primaryColor: _primaryColor != null
              ? parseColor(_primaryColor)
              : MeditoColors.walterWhite,
        ),
      ),
      body: new Builder(builder: (BuildContext context) {
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
                          !Platform.isIOS
                              ? getBGMusicRowOrContainer()
                              : Container(),
                          !Platform.isIOS
                              ? buildBackgroundMusicRow()
                              : Container(),
                          !Platform.isIOS ? buildSpacer() : Container(),
                          ////////// spacer
                          !Platform.isIOS
                              ? buildTextHeaderForRow(
                                  'Available Offline $_availableOfflineIndicatorText')
                              : Container(),
                          !Platform.isIOS ? buildOfflineRow() : Container(),
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

  Widget getBGMusicRowOrContainer() => _backgroundMusicAvailable
      ? buildTextHeaderForRow('Background Sounds')
      : Container();

  Widget getBGMusicSpacer() =>
      _backgroundMusicAvailable ? buildSpacer() : Container();

  Widget getBeginButtonContent() {
    if (downloadSingleton == null || !downloadSingleton.isValid())
      downloadSingleton = new DownloadSingleton(currentFile);
    if (downloadSingleton.isDownloadingMe(currentFile)) {
      return ValueListenableBuilder(
          valueListenable: downloadSingleton.returnNotifier(),
          builder: (context, value, widget) {
            if (value >= 1) {
              return Icon(Icons.play_arrow, color: parseColor(_secondaryColor));
            } else {
              print("Updated value: " + (value * 100).toInt().toString());
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

    if (downloadSingleton == null || !downloadSingleton.isValid())
      downloadSingleton = new DownloadSingleton(currentFile);
    addIntToSF(widget.id, 'voiceSelected', voiceSelected);
    addIntToSF(widget.id, 'lengthSelected', lengthSelected);
    addIntToSF(widget.id, 'musicSelected', _musicSelected);

    if (downloadSingleton.isDownloadingMe(currentFile) ||
        showIndeterminateSpinner ||
        _loadingThisPage) return null;

    widget.onBeginPressed(
        currentFile,
        _illustration,
        _primaryColor,
        _title,
        _description,
        _contentText,
        _secondaryColor,
        _backgroundMusicUrl,
        clockTimeToDuration(lengthList[lengthSelected]).inMilliseconds);

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
      child: Text(
        widget.title,
        style: Theme.of(context).textTheme.bodyText1,
      ),
    );
  }

  Widget buildDescriptionText() {
    return _contentText.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 16, right: 16),
            child: getDescriptionMarkdownBody(_contentText, context),
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
    if (_loadingThisPage) {
      return getEmptyPillRow();
    }
    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        shrinkWrap: true,
        itemCount: lengthList.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          return Visibility(
            visible: lengthFilteredList?.contains(lengthList[index]),
            child: Padding(
              padding: buildInBetweenChipPadding(index),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                showCheckmark: false,
                labelPadding: buildInnerChipPadding(),
                label: Text(formatSessionLength(index)),
                selected: lengthSelected == index,
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

  formatSessionLength(int index) {
    String lengthText = lengthList[index];
    if (lengthText.contains(":")) {
      var duration = clockTimeToDuration(lengthText);
      String time = "";
      if (duration.inMinutes < 1) {
        time = "<1";
      } else {
        time = duration.inMinutes.toString();
      }
      return "$time min";
    }
    return lengthList[index] + ' min';
  }

  Widget buildVoiceRow() {
    if (!_showVoiceChoice) {
      return Container();
    }

    if (_loadingThisPage) {
      return getEmptyPillRow();
    }

    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: voiceList.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: buildInBetweenChipPadding(index),
            child: FilterChip(
              shape: buildChipBorder(),
              labelPadding: buildInnerChipPadding(),
              label: Text(voiceList[index]),
              showCheckmark: false,
              selected: voiceSelected == index,
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
    voiceSelected = index;

    for (final file in filesList) {
      if (file.voice == (voiceList[index])) {
        currentFile = file;
        if (downloadSingleton == null || !downloadSingleton.isValid())
          downloadSingleton = new DownloadSingleton(currentFile);
        break;
      }
    }
    _offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    if (mounted)
      setState(() {
        filterLengthsForThisPerson(voiceList[voiceSelected],
            clockTimeToDuration(lengthList[lengthSelected]).inMinutes);
        _updateAvailableOfflineIndicatorText();
      });
  }

  Future<void> onSessionPillTap(bool value, int index) async {
    filesList.forEach((file) => {
          if (file.length == (lengthList[index]) &&
              file.voice == (voiceList[voiceSelected]))
            currentFile = file
        });
    _offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    setState(() {
      lengthSelected = index;
      _updateAvailableOfflineIndicatorText();
    });
  }

  TextStyle getLengthPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getOfflinePillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _offlineSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getMusicPillTextStyle(int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _musicSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: voiceSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.walterWhite);
  }

  void compileLists(List files) {
    this.filesList = files;
    voiceList.clear();
    lengthList.clear();

    files?.forEach((file) {
      file.url = file.url.replaceAll(' ', '%20');
      if (!voiceList.contains(file.voice)) {
        //put Will first
        if (file.voice.contains('Will')) {
          voiceList.insert(0, file.voice);
        } else {
          voiceList.add(file.voice);
        }
      }
      if (!lengthList.contains(file.length)) {
        lengthList.add(file.length);
      }
    });

    lengthList.sort((a, b) {
      if (a.contains(":")) {
        return clockTimeToDuration(a)
            .inMilliseconds
            .compareTo(clockTimeToDuration(b).inMilliseconds);
      }
      return double.parse(a).compareTo(double.parse(b));
    });

    if (voiceList != null && voiceList.isNotEmpty) {
      filterLengthsForThisPerson(voiceList[0]);
    }
  }

  void filterLengthsForThisPerson(String voiceSelected,
      [int previousMusicSelected]) {
    lengthSelected = -1;
    lengthFilteredList.clear();

    this.filesList?.forEach((file) {
      if (file.voice == voiceSelected) {
        lengthFilteredList.add(file.length);
      }
    });
    List<dynamic> roundedList = [];
    for (int i = 0; i < lengthList.length; i++) {
      roundedList.add(clockTimeToDuration(lengthList[i]).inMinutes);
    }
    if (previousMusicSelected != null)
      lengthSelected = roundedList.indexOf(previousMusicSelected);
    if (lengthSelected == -1) lengthSelected = 0;
  }

  Widget buildOfflineRow() {
    if (_loadingThisPage) {
      return getEmptyPillRow();
    }
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
              selected: _offlineSelected == index,
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
    if (!_backgroundMusicAvailable) return Container();

    if (_bgMusicList.length == 0) return getEmptyPillRow();

    return SizedBox(
        height: 56,
        child: ListView.builder(
          padding: const EdgeInsets.only(left: 16),
          shrinkWrap: true,
          itemCount: 1 + (_bgMusicList.length ?? 0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: buildInBetweenChipPadding(index),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                labelPadding: buildInnerChipPadding(),
                showCheckmark: false,
                label: Text(index == 0 ? "None" : _bgMusicList[index - 1].key),
                selected: index == _musicSelected,
                onSelected: (bool value) {
                  onMusicSelected(
                      index,
                      index > 0 ? _bgMusicList[index - 1].value : "",
                      index > 0 ? _bgMusicList[index - 1].key : "");
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
      padding: const EdgeInsets.only(left: 16.0, top: 16),
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
        pressElevation: 4,
        shape: buildChipBorder(),
        labelPadding: buildInnerChipPadding(),
        showCheckmark: false,
        label: Text("          "),
        selected: false,
        onSelected: (bool value) {},
        backgroundColor: MeditoColors.moonlight,
        selectedColor: MeditoColors.walterWhite,
      ),
    );
  }

  void onMusicSelected(int index, String url, String name) {
    _musicSelected = index;

    if (index > 0) {
      showIndeterminateSpinner = true;
      downloadBGMusicFromURL(url, name).then((value) {
        showIndeterminateSpinner = false;
        _backgroundMusicUrl = value;
        setState(() {});
      }).catchError((onError) {
        print(onError);
        showIndeterminateSpinner = false;
        _musicSelected = 0;
        _backgroundMusicUrl = null;
      });
    } else {
      showIndeterminateSpinner = false;
      _musicSelected = 0;
      _backgroundMusicUrl = null;
    }
    setState(() {});
  }

  void onOfflineSelected(int index) {
    _offlineSelected = index;

    _updateAvailableOfflineIndicatorText();

    if (downloadSingleton == null || !downloadSingleton.isValid())
      downloadSingleton = new DownloadSingleton(currentFile);
    if (index == 1) {
      // 'YES' selected
      if (!downloadSingleton.isDownloadingSomething())
        downloadSingleton.start(currentFile);
      else {
        _offlineSelected = 0;
        createSnackBarWithColor(
            "Another Download in Progress", scaffoldContext, Colors.black12);
      }
    } else {
      // 'NO' selected
      removing = true;
      removeFile(currentFile).then((onValue) {
        setState(() {
          print("Removed file");
          //removing = false;
        });
      }).catchError((onError) {
        setState(() {
          print(onError);
          _offlineSelected = 0;
        });
      });
    }
    setState(() {});
  }

  void _updateAvailableOfflineIndicatorText() {
    if (_offlineSelected != 0) {
      var time = clockTimeToDuration(lengthList[lengthSelected]).inMinutes;
      _availableOfflineIndicatorText =
          '(${voiceList[voiceSelected]} - $time min)';
    } else {
      _availableOfflineIndicatorText = "";
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
            child: _illustration == null
                ? Container()
                : getNetworkImageWidget(_illustration.url),
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

  _onFirstFutureError(dynamic error) {
    // set up the button
    Widget _errorDialogOkButton = FlatButton(
      child: Text("Go back and refresh".toUpperCase()),
      textColor: MeditoColors.lightTextColor,
      onPressed: () {
        //once to close the dialog, once to go back
        Navigator.pop(context, 'error');
        Navigator.pop(context, 'error');
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Oops!"),
      backgroundColor: MeditoColors.darkBGColor,
      content: Text("An error has occured. This session may have been moved."),
      actions: [
        _errorDialogOkButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
