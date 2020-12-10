import 'dart:math';

import 'package:Medito/utils/colors.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

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
        int duration = widget.mediaItem?.duration?.inMilliseconds ?? 0;

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
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 8;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

extension DurationExtensions on Duration {
  /// Converts the duration into a readable string
  /// 15:35
  String toMinutesSeconds() {
    String twoDigitMinutes = _toTwoDigits(this
        .inMinutes
        .remainder(100)); //NB: if it's over 100 mins it'll show 0:00!!
    String twoDigitSeconds = _toTwoDigits(this.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _toTwoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }
}
