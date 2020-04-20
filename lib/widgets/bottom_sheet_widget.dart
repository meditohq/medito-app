import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class BottomSheetWidget extends StatefulWidget {
  final Future data;
  final String title;
  final Function(dynamic, dynamic, dynamic, String, String, String)
      onBeginPressed;

  BottomSheetWidget({Key key, this.title, this.data, this.onBeginPressed})
      : super(key: key);

  @override
  _BottomSheetWidgetState createState() => _BottomSheetWidgetState();
}

class _BottomSheetWidgetState extends State<BottomSheetWidget> {
  var voiceSelected = 0;
  var lengthSelected = 0;
  List voiceList = [' ', ' ', ' '];
  List lengthList = [' ', ' ', ' '];
  List lengthFilteredList = [];
  List filesList;
  var coverArt;
  String description;
  String title;
  var coverColor;
  String contentText;

  @override
  void initState() {
    super.initState();

    widget.data.then((d) {
      this.coverArt = d?.coverArt != null ? d?.coverArt?.first : null;
      this.coverColor = d?.coverColor;
      this.title = d?.title;
      this.contentText = d?.contentText;
      this.description = d?.description;
      compileLists(d?.files);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      //this is to hide the white background behind the rounded corners
      color: MeditoColors.almostBlack,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          color: MeditoColors.darkBGColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            buildInkWell(),
            buildTitleText(context),
            buildVoiceText(context),
            buildVoiceRow(),
            buildSessionLengthText(context),
            buildSessionLengthRow(),
            buildButton(),
          ],
        ),
      ),
    );
  }

  Widget buildButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 48,
              child: FlatButton(
                onPressed: _onBeginTap,
                shape: RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(12.0),
                ),
                color: MeditoColors.lightColor,
                child: Text(
                  'BEGIN',
                  style: Theme.of(context).textTheme.display2.copyWith(
                      color: MeditoColors.darkBGColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBeginTap() {
    filesList.forEach((file) => {
          (file.length == (lengthList[lengthSelected]) &&
                  file.voice == (voiceList[voiceSelected]))
              ? widget.onBeginPressed(
                  file, coverArt, coverColor, title, description, contentText)
              : null
        });
  }

  Widget buildVoiceText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Text(
        'VOICE',
        style: Theme.of(context).textTheme.display4,
      ),
    );
  }

  Padding buildTitleText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        widget.title,
        style: Theme.of(context).textTheme.title,
      ),
    );
  }

  Widget buildSessionLengthText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 16),
      child: Text(
        'SESSION LENGTH',
        style: Theme.of(context).textTheme.display2,
      ),
    );
  }

  Widget buildSessionLengthRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: SizedBox(
        height: 56,
        child: ListView.builder(
          padding: EdgeInsets.only(right: 16),
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
                  labelStyle: getSessionPillTextStyle(context, index),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildVoiceRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: SizedBox(
        height: 56,
        child: ListView.builder(
          padding: EdgeInsets.only(right: 16),
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
      ),
    );
  }

  EdgeInsets buildInnerChipPadding() =>
      EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12);

  EdgeInsets buildInBetweenChipPadding() =>
      const EdgeInsets.only(left: 4, top: 10, bottom: 10, right: 4);

  RoundedRectangleBorder buildChipBorder() {
    return RoundedRectangleBorder(
        side: BorderSide(color: MeditoColors.lightTextColor),
        borderRadius: BorderRadius.all(Radius.circular(12)));
  }

  void onVoicePillTap(bool value, int index) {
    setState(() {
      voiceSelected = index;
      lengthSelected = 0;
      filterLengthsForThisPerson(voiceList[voiceSelected]);
    });
  }

  void onSessionPillTap(bool value, int index) {
    setState(() {
      lengthSelected = index;
    });
  }

  TextStyle getSessionPillTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.display4.copyWith(
        color: lengthSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  TextStyle getVoiceTextStyle(BuildContext context, int index) {
    return Theme.of(context).textTheme.display4.copyWith(
        color: voiceSelected == index
            ? MeditoColors.darkBGColor
            : MeditoColors.lightColor);
  }

  Widget buildInkWell() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        new Container(
          margin: EdgeInsets.only(top: 8),
          width: 48.0,
          height: 4.0,
          decoration: new BoxDecoration(
            border: new Border.all(color: MeditoColors.darkColor, width: 2.0),
            borderRadius: new BorderRadius.circular(4.0),
          ),
        ),
      ],
    );
  }

  void compileLists(List files) {
    this.filesList = files;
    voiceList.clear();
    lengthList.clear();

    files?.forEach((file) {
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
}
