import 'dart:math';

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class PositionIndicatorWidget extends StatefulWidget {
  final Color? color;
  final MeditoAudioHandler? handler;

  PositionIndicatorWidget({Key? key, this.handler, this.color})
      : super(key: key);

  @override
  _PositionIndicatorWidgetState createState() =>
      _PositionIndicatorWidgetState();
}

class _PositionIndicatorWidgetState extends State<PositionIndicatorWidget> {

  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double?> _dragPositionSubject =
      BehaviorSubject.seeded(null);

  @override
  Widget build(BuildContext context) {

    double? _seekPos;

    return StreamBuilder(
      stream: Rx.combineLatest2<double?, double, double?>(
          _dragPositionSubject.stream,
          Stream.periodic(Duration(milliseconds: 200), (count) => count.toDouble()),
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
                    trackHeight: 4,
                    trackShape: CustomTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
                  ),
                  child: Slider(
                    min: 0.0,
                    activeColor: widget.color,
                    inactiveColor: MeditoColors.meditoTextGrey,
                    max: duration.toDouble(),
                    value: _seekPos ??
                        max(0.0, min(position.toDouble(), duration.toDouble())),
                    onChanged: (value) {
                      _dragPositionSubject.add(value);
                    },
                    onChangeEnd: (value) {
                      widget.handler?.seek(Duration(milliseconds: value.toInt()));
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            Duration(milliseconds: position).toMinutesSeconds(),
            style: Theme.of(context)
                .textTheme
                .subtitle2
                ?.copyWith(color: MeditoColors.meditoTextGrey),
          ),
          Text(
            Duration(milliseconds: duration).toMinutesSeconds(),
            style: Theme.of(context)
                .textTheme
                .subtitle2
                ?.copyWith(color: MeditoColors.meditoTextGrey),
          ),
        ],
      ),
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
      trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2 + 8;
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
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 2}) {
    super.paint(context, offset,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        textDirection: textDirection,
        thumbCenter: thumbCenter,
        additionalActiveTrackHeight: 0);
  }
}
