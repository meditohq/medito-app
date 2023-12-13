import 'dart:math';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DurationIndicatorWidget extends ConsumerStatefulWidget {
  const DurationIndicatorWidget({
    super.key,
    required this.file,
    required this.trackId,
  });

  final TrackFilesModel file;
  final String trackId;

  @override
  ConsumerState<DurationIndicatorWidget> createState() =>
      _DurationIndicatorWidgetState();
}

class _DurationIndicatorWidgetState
    extends ConsumerState<DurationIndicatorWidget> {
  final _minSeconds = 0.0;
  double? _dragSeekbarValue;
  double _maxDuration = 0.0;
  bool _draggingSeekbar = false;

  @override
  Widget build(BuildContext context) {
    final audioPositionAndPlayerState =
        ref.watch(audioPositionAndPlayerStateProvider);
    final audioPlayerNotifier = ref.watch(audioPlayerNotifierProvider);

    _maxDuration = widget.file.duration.toDouble();

    return audioPositionAndPlayerState.when(
      data: (data) {
        final value = min(
          _dragSeekbarValue ?? data.position.inMilliseconds,
          _maxDuration,
        );
        if (_dragSeekbarValue != null && !_draggingSeekbar) {
          _dragSeekbarValue = null;
        }
        audioPlayerNotifier.handleFadeAtEnd(
          data.position,
          Duration(milliseconds: _maxDuration.round()),
        );

        return _durationBar(context, ref, value, data);
      },
      error: (error, stackTrace) => SizedBox(),
      loading: () => SizedBox(),
    );
  }

  void onChangeEnd(
    WidgetRef ref,
    PositionAndPlayerStateState data,
    double val,
  ) {
    ref.read(slideAudioPositionProvider(
      duration: val.round(),
    ));
    _draggingSeekbar = false;
    ref.read(audioPlayerNotifierProvider).handleFadeAtEnd(
          data.position,
          Duration(milliseconds: _maxDuration.round()),
        );
  }

  Padding _durationBar(
    BuildContext context,
    WidgetRef ref,
    num currentDuration,
    PositionAndPlayerStateState data,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, top: 0, bottom: 0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              trackShape: CustomTrackShape(addTopPadding: false),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 6.0,
              ),
            ),
            child: Slider(
              min: _minSeconds,
              activeColor: ColorConstants.walterWhite,
              inactiveColor: ColorConstants.onyx,
              max: _maxDuration,
              value: currentDuration.toDouble(),
              onChanged: (val) {
                if (!_draggingSeekbar) {
                  _draggingSeekbar = true;
                }
                setState(() {
                  _dragSeekbarValue = val;
                });
              },
              onChangeEnd: (val) => onChangeEnd(ref, data, val),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -14),
            child: _durationLabels(
              context,
              currentDuration.round(),
              _maxDuration.round(),
            ),
          ),
        ],
      ),
    );
  }

  Row _durationLabels(
    BuildContext context,
    int position,
    int duration,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _durationLabel(
          context,
          Duration(milliseconds: position).toMinutesSeconds(),
        ),
        _durationLabel(
          context,
          Duration(milliseconds: duration).toMinutesSeconds(),
        ),
      ],
    );
  }

  Text _durationLabel(
    BuildContext context,
    String label,
  ) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ColorConstants.graphite,
            fontFamily: DmMono,
            fontSize: 12,
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
    var boxHeight = parentBox.size.height;
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    var trackTop;
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
