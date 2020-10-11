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
import 'package:Medito/data/page.dart';
import 'package:Medito/viewmodel/bottom_sheet_view_model.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../audioplayer/player_utils.dart';
import '../utils/colors.dart';
import '../utils/utils.dart';

class SessionOptionsScreen extends StatefulWidget {
  final Future data;
  final String title;
  final Function(
          Files, Illustration, dynamic, String, String, String, String, String)
      onBeginPressed;

  SessionOptionsScreen({Key key, this.title, this.data, this.onBeginPressed})
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

  bool _loadingThisPage = true;
  final _viewModel = new BottomSheetViewModelImpl();

  List _bgMusicList = [];

  @override
  void initState() {
    super.initState();

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
      floatingActionButton: PlayerButton(
        onPressed: _onBeginTap,
        child: SizedBox(width: 24, height: 24, child: getBeginButtonContent()),
        primaryColor: _primaryColor != null
            ? parseColor(_primaryColor)
            : MeditoColors.lightColor,
      ),
      body: Container(
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
                        buildTextHeaderForRow('Available Offline'),
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
      ),
    );
  }

  Widget getBGMusicRowOrContainer() => _backgroundMusicAvailable
      ? buildTextHeaderForRow('Background Sounds')
      : Container();

  Widget getBGMusicSpacer() =>
      _backgroundMusicAvailable ? buildSpacer() : Container();

  Widget getBeginButtonContent() {
    if(downloadSingleton==null || !downloadSingleton.isValid()) downloadSingleton = new DownloadSingleton(currentFile);
    if (downloadSingleton.isDownloadingMe(currentFile)) {
      return ValueListenableBuilder(
          valueListenable: downloadSingleton.returnNotifier(),
          builder: (context, value, widget) {
            if (value >= 1) {
              return Icon(Icons.play_arrow, color: parseColor(_secondaryColor));
            }
            else {
              print("Updated value: " + (value * 100).toInt().toString());
              return Text((value * 100).toInt().toString() + "%",
                  style: TextStyle(color: parseColor(_secondaryColor), fontSize: 11));
            }
          });
    }
    // }
    // else if (downloadSingleton.isDownloadingSomething()) {
    //   return ValueListenableBuilder(valueListenable: downloadSingleton.returnNotifier(),
    //       builder:(context, value, widget){
    //         if(value>=1){
    //           return Text(
    //             'BEGIN',
    //             style: Theme.of(context).textTheme.headline3.copyWith(
    //                 color: _secondaryColor != null && _secondaryColor.isNotEmpty
    //                     ? parseColor(_secondaryColor)
    //                     : MeditoColors.darkBGColor,
    //                 fontWeight: FontWeight.bold),
    //           );
    //         }
    //         else{
    //           print("Updated value: " + (value*100).toInt().toString());
    //           return SizedBox(
    //             height: 24,
    //             width: 24,
    //             child: CircularProgressIndicator(
    //                 valueColor: AlwaysStoppedAnimation<Color>(parseColor(_secondaryColor))),
    //           );
    //         }
    //       });
    // }
    else if (showIndeterminateSpinner || removing){
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
    if(downloadSingleton==null || !downloadSingleton.isValid()) downloadSingleton = new DownloadSingleton(currentFile);
    if (downloadSingleton.isDownloadingMe(currentFile) || showIndeterminateSpinner || _loadingThisPage) return null;

    widget.onBeginPressed(currentFile, _illustration, _primaryColor, _title,
        _description, _contentText, _secondaryColor, _backgroundMusicUrl);

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
        style: Theme.of(context).textTheme.bodyText1.copyWith(
            letterSpacing: 0.2,
            height: 1.5,
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w600),
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
                label: Text(lengthList[index] + ' min'),
                selected: lengthSelected == index,
                onSelected: (bool value) {
                  onSessionPillTap(value, index);
                },
                backgroundColor: MeditoColors.moonlight,
                selectedColor: MeditoColors.lightColor,
                labelStyle: getLengthPillTextStyle(context, index),
              ),
            ),
          );
        },
      ),
    );
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
              selectedColor: MeditoColors.lightColor,
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
    lengthSelected = 0;
    voiceSelected = index;
    for (final file in filesList) {
      if (file.voice == (voiceList[index])) {
        currentFile = file;
        if(downloadSingleton==null || !downloadSingleton.isValid()) downloadSingleton = new DownloadSingleton(currentFile);
        break;
      }
    }
    _offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    if (mounted)
      setState(() {
        filterLengthsForThisPerson(voiceList[voiceSelected]);
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
    });
  }

  TextStyle getLengthPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getOfflinePillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _offlineSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getMusicPillTextStyle(int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: _musicSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        fontSize: 16.0,
        color: voiceSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
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
      return double.parse(a).compareTo(double.parse(b));
    });

    if (voiceList != null && voiceList.isNotEmpty) {
      filterLengthsForThisPerson(voiceList[0]);
    }
  }

  void filterLengthsForThisPerson(String voiceSelected) {
    lengthFilteredList.clear();

    this.filesList?.forEach((file) {
      if (file.voice == voiceSelected) {
        lengthFilteredList.add(file.length);
      }
    });

    lengthSelected = lengthList.indexOf(lengthFilteredList.first);
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
              selectedColor: MeditoColors.lightColor,
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
                selectedColor: MeditoColors.lightColor,
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
        onSelected: null,
        shape: buildChipBorder(),
        padding: buildInnerChipPadding(),
        label: Text("        "),
        selected: true,
        showCheckmark: false,
        selectedColor: MeditoColors.moonlight,
        labelStyle: getMusicPillTextStyle(0),
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
    if(downloadSingleton==null || !downloadSingleton.isValid()) downloadSingleton = new DownloadSingleton(currentFile);
    if (index == 1) {
      // 'YES' selected
      if(!downloadSingleton.isDownloadingSomething()) downloadSingleton.start(currentFile);
      else {
        _offlineSelected = 0;
        Fluttertoast.showToast(
            msg: "Another Download in Progress",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER
        );
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

  Widget buildImage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
      child: Container(
          height: 100,
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
