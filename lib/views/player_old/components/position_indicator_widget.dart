import 'dart:math';
import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/network/player/player_bloc.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            _buildDurationLabels(context, duration, position),
            if (duration != null)
              Padding(
                padding:
                    const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    trackShape:
                        //  RoundedRectSliderTrackShape(),
                        CustomTrackShape(),
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: 5.0,
                    ),
                  ),
                  child: Slider(
                    min: 0.0,
                    activeColor: ColorConstants.walterWhite,
                    inactiveColor: ColorConstants.greyIsTheNewGrey,
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
            _buildBottomLabels(context, duration, position),
          ],
        );
      },
    );
  }

  Padding _buildDurationLabels(
      BuildContext context, int duration, int position) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Transform.translate(
        offset: Offset(0, 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _getDurationLabel(
              context,
              Duration(milliseconds: position).toMinutesSeconds(),
            ),
            _getDurationLabel(
              context,
              Duration(milliseconds: duration).toMinutesSeconds(),
            ),
          ],
        ),
      ),
    );
  }

  Text _getDurationLabel(
    BuildContext context,
    String label,
  ) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: ColorConstants.walterWhite, fontFamily: DmMono, fontSize: 14),
    );
  }

  Padding _buildBottomLabels(BuildContext context, int duration, int position) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _getBottomActionLabel(
            context,
            // duration,
            _currentSpeed,
            () => {widget.handler?.setPlayerSpeed(_getNextSpeed())},
          ),
          width8,
          _getBottomActionLabel(
            context,
            'DONWLOAD',
            () => {},
          ),
          width8,
          if (_hasBGSound())
            _getBottomActionLabel(
              context,
              'SOUND',
              () => _onBgMusicPressed(context),
            ),
          if (_hasBGSound()) width8,
        ],
      ),
    );
  }

  Expanded _getBottomActionLabel(
      BuildContext context, String label, void Function()? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: ColorConstants.greyIsTheNewGrey,
            borderRadius: BorderRadius.all(
              Radius.circular(3),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorConstants.walterWhite,
                fontFamily: DmMono,
                fontSize: 14),
          ),
        ),
      ),
    );
  }

  bool _hasBGSound() => widget.handler?.mediaItemHasBGSound() == true;

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
    var location = GoRouter.of(context).location;
    context.go(location + backgroundSounds);
    // var bloc = PlayerBloc();

    // // slight delay in case the cache returns before the sheet opens
    // Future.delayed(Duration(milliseconds: 50))
    //     .then((value) => bloc.fetchBackgroundSounds());
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: true,
    //   builder: (context) => ChooseBackgroundSoundDialog(
    //       handler: widget.handler, stream: bloc.bgSoundsListController?.stream),
    // );
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
