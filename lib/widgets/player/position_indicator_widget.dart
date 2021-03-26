import 'dart:math';

import 'package:Medito/utils/colors.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:Medito/utils/duration_ext.dart';

class PositionIndicatorWidget extends StatefulWidget {
  final MediaItem mediaItem;
  final PlaybackState state;
  final Color color;

  PositionIndicatorWidget({Key key, this.state, this.mediaItem, this.color})
      : super(key: key);

  @override
  _PositionIndicatorWidgetState createState() =>
      _PositionIndicatorWidgetState();
}

class _PositionIndicatorWidgetState extends State<PositionIndicatorWidget> {
  double position;

  /// Tracks the position while the user drags the seek bar.
  final BehaviorSubject<double> _dragPositionSubject =
      BehaviorSubject.seeded(null);

  @override
  void dispose() {
    super.dispose();
  }

  bool tracked = false;

  @override
  Widget build(BuildContext context) {
    double seekPos;
    return StreamBuilder(
      stream: Rx.combineLatest2<double, double, double>(
          _dragPositionSubject.stream,
          Stream.periodic(Duration(milliseconds: 200)),
          (dragPosition, _) => dragPosition),
      builder: (context, snapshot) {
        double position = snapshot.data ??
            widget.state?.currentPosition?.inMilliseconds?.toDouble() ??
            0;
        var duration = widget.mediaItem?.duration?.inMilliseconds ?? 0;

        if (position > duration - 10 && !tracked) {
          tracked = true;
        }

        return Column(
          children: [
            if (duration != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackShape: CustomTrackShape(),
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
                  ),
                  child: Slider(
                    min: 0.0,
                    activeColor: widget.color,
                    inactiveColor: MeditoColors.walterWhite.withOpacity(0.7),
                    max: duration.toDouble(),
                    value: seekPos ??
                        max(0.0, min(position.toDouble(), duration.toDouble())),
                    onChanged: (value) {
                      _dragPositionSubject.add(value);
                    },
                    onChangeEnd: (value) {
                      AudioService.seekTo(
                          Duration(milliseconds: value.toInt()));
                      seekPos = value;
                      _dragPositionSubject.add(null);
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      Duration(
                              milliseconds: widget
                                      .state?.currentPosition?.inMilliseconds ??
                                  0)
                          .toMinutesSeconds(),
                      style: Theme.of(context).textTheme.headline1.copyWith(
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w500,
                          color: MeditoColors.walterWhite.withOpacity(0.7),
                          height: 1.4)),
                  Text(
                    Duration(milliseconds: duration).toMinutesSeconds(),
                    style: Theme.of(context).textTheme.headline1.copyWith(
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w500,
                        color: MeditoColors.walterWhite.withOpacity(0.7),
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight;
    final trackLeft = offset.dx;
    final trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 8;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

