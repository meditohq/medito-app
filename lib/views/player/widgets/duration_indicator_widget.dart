import 'package:medito/constants/constants.dart';
import 'package:medito/utils/duration_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';

class DurationIndicatorWidget extends ConsumerStatefulWidget {
  const DurationIndicatorWidget({super.key, required this.onSeekEnd});

  final void Function(int) onSeekEnd;

  @override
  ConsumerState<DurationIndicatorWidget> createState() =>
      _DurationIndicatorWidgetState();
}

class _DurationIndicatorWidgetState
    extends ConsumerState<DurationIndicatorWidget> {
  bool _isSeekbarBeingDragged = false;
  double _dragSeekbarValue = 0;

  @override
  Widget build(BuildContext context) {
    final totalDuration = ref.watch(
      audioStateProvider.select((s) => s.duration),
    );
    final currentPosition = ref.watch(
      audioStateProvider.select((s) => s.position),
    );

    // clamp values to avoid negative slider values
    final safeTotal = totalDuration < 0 ? 0 : totalDuration;
    final safePosition = currentPosition < 0 ? 0 : currentPosition;

    return _durationBar(
      context,
      // 99 is to avoid rounding errors which would result in the current
      // position being larger that the total duration
      safeTotal / 99,
      safePosition / 100,
      safeTotal,
      safePosition,
    );
  }

  Padding _durationBar(
    BuildContext context,
    double totalDuration,
    double currentDuration,
    int rawTotalDuration,
    int rawCurrentPosition,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, top: 0, bottom: 0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              trackShape: CustomTrackShape(addTopPadding: false),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            ),
            child: Slider(
              min: 0.0,
              max: totalDuration > 0.0 ? totalDuration : 1.0,
              activeColor: ColorConstants.white,
              inactiveColor: ColorConstants.onyx,
              value: _isSeekbarBeingDragged
                  ? _dragSeekbarValue
                  : currentDuration.clamp(
                      0.0,
                      (totalDuration > 0.0 ? totalDuration : 1.0),
                    ),
              onChanged: (val) {
                if (!_isSeekbarBeingDragged) {
                  _isSeekbarBeingDragged = true;
                }
                setState(() {
                  _dragSeekbarValue = val;
                });
              },
              onChangeEnd: _onChangeEnd,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: _durationLabels(
              context,
              rawTotalDuration,
              rawCurrentPosition,
            ),
          ),
        ],
      ),
    );
  }

  void _onChangeEnd(double val) {
    _isSeekbarBeingDragged = false;
    widget.onSeekEnd((val * 100).toInt());
  }

  Row _durationLabels(
    BuildContext context,
    int totalDuration,
    int currentPosition,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _durationLabel(
          context,
          Duration(milliseconds: currentPosition.round()).toMinutesSeconds(),
        ),
        _durationLabel(
          context,
          Duration(milliseconds: totalDuration.round()).toMinutesSeconds(),
        ),
      ],
    );
  }

  Text _durationLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: ColorConstants.white,
        fontFamily: dmMono,
        fontSize: 12,
      ),
    );
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  CustomTrackShape({this.addTopPadding = true});

  bool addTopPadding;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    var boxHeight = parentBox.size.height;
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    double trackTop;
    trackTop = addTopPadding
        ? offset.dy + (boxHeight - trackHeight) / 2 + 6
        : boxHeight / 2 - 2;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      additionalActiveTrackHeight: 0,
    );
  }
}
