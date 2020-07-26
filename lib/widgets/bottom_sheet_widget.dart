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

import 'package:Medito/viewmodel/bottom_sheet_view_model.dart';
import 'package:flutter/material.dart';

import '../audioplayer/player_utils.dart';
import '../utils/colors.dart';
import '../utils/utils.dart';
import 'pill_utils.dart';

class BottomSheetWidget extends StatefulWidget {
  final Future data;
  final String title;
  final Function(
          dynamic, dynamic, dynamic, String, String, String, String, String)
      onBeginPressed;

  BottomSheetWidget({Key key, this.title, this.data, this.onBeginPressed})
      : super(key: key);

  @override
  _BottomSheetWidgetState createState() => _BottomSheetWidgetState();
}

class _BottomSheetWidgetState extends State<BottomSheetWidget> {
  var voiceSelected = 0;
  var lengthSelected = 0;
  var _offlineSelected = 0;
  var _musicSelected = 0;
  List voiceList = [' ', ' ', ' '];
  List lengthList = [' ', ' ', ' '];
  List lengthFilteredList = [];
  List filesList;
  var _coverArt;
  String _description;
  String _title;
  var _coverColor;
  String _textColor;
  String _contentText = '';
  bool _downloading = false;
  var currentFile;
  var _backgroundMusicUrl;
  var _backgroundMusicAvailable = false;

  bool _showVoiceChoice = true;

  bool _loading = true;
  final _viewModel = new BottomSheetViewModelImpl();

  @override
  void initState() {
    super.initState();

    widget.data.then((d) {
      this._coverArt = d?.coverArt != null ? d?.coverArt?.first : null;
      this._coverColor = d?.coverColor;
      this._title = d?.title;
      this._textColor = d?.textColor;
      this._contentText = d?.contentText;
      this._description = d?.description;
      compileLists(d?.files);
      onVoicePillTap(true, 0);
      setState(() {
        this._backgroundMusicAvailable = d?.backgroundMusic;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (voiceList.length == 1 &&
        voiceList[0].toString().toLowerCase() == 'no voice') {
      _showVoiceChoice = false;
    }

    return Scaffold(
      backgroundColor: MeditoColors.darkBGColor,
      body: Container(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      buildGoBackPill(),
                      buildImage(),
                      buildTitleText(),
                      buildDescriptionText(),
                      _showVoiceChoice ? buildSpacer() : Container(),
                      buildVoiceText(),
                      buildVoiceRow(),
                      buildSpacer(),
                      ////////// spacer
                      buildSessionLengthText(),
                      buildSessionLengthRow(),
                      getBGMusicSpacer(),
                      ////////// spacer
//                      getBGMusicRowOrContainer(),
//                      buildBackgroundMusicRow(),
//                      buildSpacer(),
                      ////////// spacer
                      buildOfflineTextRow(),
                      buildOfflineRow(),
                      Container(height: 80)
                    ],
                  ),
                ),
              ),
              Align(alignment: Alignment.bottomCenter, child: buildButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget getBGMusicRowOrContainer() =>
      _backgroundMusicAvailable ? buildBGMusicTextRow() : Container();

  Widget getBGMusicSpacer() =>
      _backgroundMusicAvailable ? buildSpacer() : Container();

  Widget buildButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 10),
                    color: MeditoColors.darkBGColor,
                    spreadRadius: 25,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: FlatButton(
                onPressed: _onBeginTap,
                shape: RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(12.0),
                ),
                color: _coverColor != null
                    ? parseColor(_coverColor)
                    : MeditoColors.lightColor,
                child: getBeginButtonContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getBeginButtonContent() {
    if (_downloading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(MeditoColors.darkBGColor)),
      );
    } else {
      return Text(
        'BEGIN',
        style: Theme.of(context).textTheme.headline3.copyWith(
            color: _textColor != null && _textColor.isNotEmpty
                ? parseColor(_textColor)
                : MeditoColors.darkBGColor,
            fontWeight: FontWeight.bold),
      );
    }
  }

  void _onBeginTap() {
    if (_downloading) return;

    widget.onBeginPressed(currentFile, _coverArt, _coverColor, _title,
        _description, _contentText, _textColor, _backgroundMusicUrl);
  }

  Widget buildVoiceText() {
    if (!_showVoiceChoice) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Text(
        _loading ? '' : 'VOICE',
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }

  Widget buildTitleText() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8, right: 8),
      child: Text(
        widget.title,
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }

  Widget buildDescriptionText() {
    return _contentText.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 8, right: 8),
            child: getMarkdownBody(_contentText, context),
          )
        : Container();
  }

  Widget buildSessionLengthText() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Text(
        'SESSION LENGTH',
        style: Theme.of(context).textTheme.headline3,
      ),
    );
  }

  Widget buildOfflineTextRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Text(
        'AVAILABLE OFFLINE',
        style: Theme.of(context).textTheme.headline3,
      ),
    );
  }

  Widget buildBGMusicTextRow() {
    if (!_backgroundMusicAvailable) return Container();
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Text(
        'BACKGROUND MUSIC   🎉',
        style: Theme.of(context).textTheme.headline3,
      ),
    );
  }

  Widget buildSessionLengthRow() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: EdgeInsets.only(right: 16, left: 8),
        shrinkWrap: true,
        itemCount: lengthList.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          return Visibility(
            visible: lengthFilteredList?.contains(lengthList[index]),
            child: Padding(
              padding: buildInBetweenChipPadding(),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                padding: buildInnerChipPadding(),
                label: Text(lengthList[index] + ' mins'),
                selected: lengthSelected == index,
                onSelected: (bool value) {
                  onSessionPillTap(value, index);
                },
                backgroundColor: MeditoColors.darkColor,
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

    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: EdgeInsets.only(right: 16, left: 8),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: voiceList.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: buildInBetweenChipPadding(),
            child: FilterChip(
              shape: buildChipBorder(),
              padding: buildInnerChipPadding(),
              label: Text(voiceList[index]),
              selected: voiceSelected == index,
              onSelected: (bool value) {
                onVoicePillTap(value, index);
              },
              backgroundColor: MeditoColors.darkColor,
              selectedColor: MeditoColors.lightColor,
              labelStyle: getVoiceTextStyle(context, index),
            ),
          );
        },
      ),
    );
  }

  EdgeInsets buildInnerChipPadding() =>
      EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12);

  EdgeInsets buildInBetweenChipPadding() =>
      const EdgeInsets.only(top: 10, bottom: 10, right: 8);

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
        break;
      }
    }
    _offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
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
        color: lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getOfflinePillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        color: _offlineSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getMusicPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
        color: _musicSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.headline1.copyWith(
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

    if (this.mounted) {
      _loading = false;
      setState(() {});
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
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SizedBox(
        height: 56,
        child: ListView.builder(
          padding: EdgeInsets.only(right: 16),
          shrinkWrap: true,
          itemCount: 2,
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: buildInBetweenChipPadding(),
              child: FilterChip(
                pressElevation: 4,
                shape: buildChipBorder(),
                padding: buildInnerChipPadding(),
                label: Text(index == 0 ? 'NO' : 'YES'),
                selected: _offlineSelected == index,
                onSelected: (bool value) {
                  onOfflineSelected(index);
                },
                backgroundColor: MeditoColors.darkColor,
                selectedColor: MeditoColors.lightColor,
                labelStyle: getOfflinePillTextStyle(context, index),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildBackgroundMusicRow() {
    if (!_backgroundMusicAvailable) return Container();

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: SizedBox(
        height: 56,
        child: FutureBuilder<List>(
            future: _viewModel.getBackgroundMusic(),
            builder: (context, snapshot) {
              return ListView.builder(
                padding: EdgeInsets.only(right: 16),
                shrinkWrap: true,
                itemCount: 1 + (snapshot.data?.length ?? 0),
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: buildInBetweenChipPadding(),
                    child: FilterChip(
                      pressElevation: 4,
                      shape: buildChipBorder(),
                      padding: buildInnerChipPadding(),
                      label: Text(
                          index == 0 ? "None" : snapshot.data[index - 1].key),
                      selected: index == _musicSelected,
                      onSelected: (bool value) {
                        onMusicSelected(index,
                            index > 0 ? snapshot.data[index - 1].value : "");
                      },
                      backgroundColor: MeditoColors.darkColor,
                      selectedColor: MeditoColors.lightColor,
                      labelStyle: getMusicPillTextStyle(context, index),
                    ),
                  );
                },
              );
            }),
      ),
    );
  }

  void onMusicSelected(int index, String url) {
    _musicSelected = index;
    _backgroundMusicUrl = url;
    setState(() {});
  }

  void onOfflineSelected(int index) {
    _offlineSelected = index;
    _downloading = true;
    if (index == 1) {
      downloadFile(currentFile).then((onValue) {
        setState(() {
          _downloading = false;
        });
      }).catchError((onError) {
        setState(() {
          print(onError);
          _downloading = false;
          _offlineSelected = 0;
        });
      });
    } else {
      removeFile(currentFile).then((onValue) {
        setState(() {
          _downloading = false;
        });
      }).catchError((onError) {
        setState(() {
          print(onError);
          _downloading = false;
          _offlineSelected = 0;
        });
      });
    }
    setState(() {});
  }

  Widget buildImage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: <Widget>[
          Expanded(
              child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    color: _coverColor != null
                        ? parseColor(_coverColor)
                        : MeditoColors.darkColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(26.0),
                    child: _coverArt == null
                        ? Container()
                        : getNetworkImageWidget(_coverArt.url),
                  ))),
        ],
      ),
    );
  }

  Widget buildSpacer() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16.0, left: 8, right: 8),
      child: Row(
        children: <Widget>[
          Expanded(
              child: Container(color: MeditoColors.lightColorLine, height: 1)),
        ],
      ),
    );
  }

  Widget buildGoBackPill() {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            padding: getEdgeInsets(1, 1),
            decoration: getBoxDecoration(1, 1, color: MeditoColors.darkColor),
            child: getTextLabel("<- Back", 1, 1, context),
          )),
    );
  }
}
