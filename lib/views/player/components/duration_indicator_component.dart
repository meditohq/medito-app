import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/duration_extensions.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DurationIndicatorComponent extends ConsumerWidget {
  const DurationIndicatorComponent({super.key, required this.file});
  final SessionFilesModel file;
  final minSeconds = 0.0;
  final additionalMilliSeconds = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlayerPositionProvider = ref.watch(audioPositionProvider);

    return audioPlayerPositionProvider.when(
      data: (data) => _durationBar(context, ref, data),
      error: (error, stackTrace) => SizedBox(),
      loading: () => SizedBox(),
    );
  }

  Padding _durationBar(
    BuildContext context,
    WidgetRef ref,
    int currentDuration,
  ) {
    var maxDuration = file.duration.toDouble();
    _handleAudioCompletion(
      currentDuration.toInt(),
      maxDuration.toInt(),
      ref,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              trackShape: CustomTrackShape(),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 5.0,
              ),
            ),
            child: Slider(
              min: minSeconds,
              activeColor: ColorConstants.walterWhite,
              inactiveColor: ColorConstants.greyIsTheNewGrey,
              max: maxDuration,
              value: currentDuration.toDouble(),
              onChanged: (value) {
                ref.read(slideAudioPositionProvider(
                  duration: value.toInt(),
                ));
              },
            ),
          ),
          _durationLabels(context, file.duration, currentDuration),
        ],
      ),
    );
  }

  void _handleAudioCompletion(
    int currentDuration,
    int maxDuration,
    WidgetRef ref,
  ) {
    if (maxDuration <= currentDuration + additionalMilliSeconds) {
      final audioProvider = ref.watch(audioPlayerNotifierProvider);
      audioProvider.seekValueFromSlider(0);
      audioProvider.pause();
      audioProvider.pauseBackgroundSound();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioPlayPauseStateProvider.notifier).state =
            PLAY_PAUSE_AUDIO.PAUSE;
      });
    }
  }

  Row _durationLabels(BuildContext context, int duration, int position) {
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
            color: ColorConstants.walterWhite,
            fontFamily: DmMono,
            fontSize: 14,
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
        ? offset.dy + (boxHeight - trackHeight) / 2 + 12
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