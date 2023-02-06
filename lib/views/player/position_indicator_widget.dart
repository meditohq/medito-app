import 'dart:math';

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'background_sounds_sheet_widget.dart';

class PositionIndicatorWidget extends StatefulWidget {
  final MeditoAudioHandler? handler;
  final Stream? bgSoundsStream;

  PositionIndicatorWidget({Key? key, this.handler, this.bgSoundsStream})
      : super(key: key);

  @override
  _PositionIndicatorWidgetState createState() =>
      _PositionIndicatorWidgetState();
}

class _PositionIndicatorWidgetState extends State<PositionIndicatorWidget> {
  final _speedList = ['X1', 'X1.25', 'X1.5', 'X2', 'X0.6'];
  var _currentSpeed = 'X1';

  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double?> _dragPositionSubject =
      BehaviorSubject.seeded(null);

  @override
  Widget build(BuildContext context) {
    double? _seekPos;

    return StreamBuilder(
      stream: Rx.combineLatest2<double?, double, double?>(
          _dragPositionSubject.stream,
          Stream.periodic(
              Duration(milliseconds: 200), (count) => count.toDouble()),
          (dragPosition, _) => dragPosition),
      builder: (context, AsyncSnapshot<double?> snapshot) {
        //snapshot.data will be non null if slider was dragged
        var position = snapshot.data?.toInt() ??
            widget.handler?.playbackState.value.position.inMilliseconds ??
            0;

        //actual duration of the audio
        var duration = widget.handler?.mediaItem.value?.extras?[DURATION] ?? 0;

        return Column(
          children: [
            if (duration != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    trackShape: CustomTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
                  ),
                  child: Slider(
                    min: 0.0,
                    activeColor: MeditoColors.walterWhite,
                    inactiveColor: MeditoColors.greyIsTheNewGrey,
                    max: duration.toDouble(),
                    value: _seekPos ??
                        max(0.0, min(position.toDouble(), duration.toDouble())),
                    onChanged: (value) {
                      _dragPositionSubject.add(value);
                    },
                    onChangeEnd: (value) {
                      widget.handler
                          ?.seek(Duration(milliseconds: value.toInt()));
                      _seekPos = value;
                      _dragPositionSubject.add(null); // todo is this ok?
                    },
                  ),
                ),
              ),
            _buildLabels(context, duration, position),
          ],
        );
      },
    );
  }

  Padding _buildLabels(BuildContext context, int duration, int position) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _getCurrentPositionLabel(position, context),
          Container(width: 8),
          _getSpeedLabel(duration, context),
          Container(width: 8),
          if (_hasBGSound()) _getSoundLabel(),
          if (_hasBGSound()) Container(width: 8),
          _getFullDurationLabel(duration, context),
        ],
      ),
    );
  }

  bool _hasBGSound() => widget.handler?.mediaItemHasBGSound() == true;

  Expanded _getFullDurationLabel(int duration, BuildContext context) {
    return Expanded(
      flex: 25,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MeditoColors.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        child: Text(
          Duration(milliseconds: duration).toMinutesSeconds(),
          style: Theme.of(context)
              .textTheme
              .subtitle2
              ?.copyWith(color: MeditoColors.walterWhite),
        ),
      ),
    );
  }

  Expanded _getCurrentPositionLabel(int position, BuildContext context) {
    return Expanded(
      flex: 25,
      child: Container(
        alignment: Alignment.center,
        height: 40,
        decoration: BoxDecoration(
          color: MeditoColors.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        child: Text(
          Duration(milliseconds: position).toMinutesSeconds(),
          style: Theme.of(context)
              .textTheme
              .subtitle2
              ?.copyWith(color: MeditoColors.walterWhite),
        ),
      ),
    );
  }

  Widget _getSpeedLabel(int duration, BuildContext context) {
    return Expanded(
      flex: 25,
      child: GestureDetector(
        onTap: () => {widget.handler?.setPlayerSpeed(_getNextSpeed())},
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: MeditoColors.walterWhite,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          alignment: Alignment.center,
          child: Text(
            _currentSpeed,
            style: Theme.of(context)
                .textTheme
                .subtitle2
                ?.copyWith(color: MeditoColors.greyIsTheNewGrey),
          ),
        ),
      ),
    );
  }

  Widget _getSoundLabel() {
    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () => _onBgMusicPressed(context),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MeditoColors.walterWhite,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          child: Text(
            'SOUND',
            style: Theme.of(context)
                .textTheme
                .subtitle2
                ?.copyWith(color: MeditoColors.greyIsTheNewGrey),
          ),
        ),
      );
    });
  }

  double _getNextSpeed() {
    var nextIndex = _speedList.indexOf(_currentSpeed) + 1;
    if (nextIndex >= _speedList.length) {
      _currentSpeed = _speedList[0];
    } else {
      _currentSpeed = _speedList[nextIndex];
    }

    setState(() {
      _currentSpeed;
    });
    return _getSpeedDoubleFromString(_currentSpeed);
  }

  double _getSpeedDoubleFromString(String current) {
    if (current == 'X1') {
      return 1;
    } else if (current == 'X1.25') {
      return 1.25;
    } else if (current == 'X1.5') {
      return 1.5;
    } else if (current == 'X2') {
      return 2;
    } else if (current == 'X0.6') {
      return 0.6;
    } else if (current == 'X0.75') {
      return 1;
    } else {
      return 0.75;
    }
  }

  void _onBgMusicPressed(BuildContext context) {
    var bloc = PlayerBloc();

    // slight delay in case the cache returns before the sheet opens
    Future.delayed(Duration(milliseconds: 50))
        .then((value) => bloc.fetchBackgroundSounds());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChooseBackgroundSoundDialog(
          handler: widget.handler, stream: bloc.bgSoundsListController?.stream),
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  CustomTrackShape({this.addTopPadding = true});

  final addTopPadding;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    var trackTop;
    if (addTopPadding) {
      trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2 + 12;
    } else {
      trackTop = parentBox.size.height / 2 - 2;
    }
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 0}) {
    super.paint(context, offset,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        textDirection: textDirection,
        thumbCenter: thumbCenter,
        additionalActiveTrackHeight: 0);
  }
}
