import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DurationIndicatorComponent extends ConsumerWidget {
  const DurationIndicatorComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(audioPlayerNotifierProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: StreamBuilder<Duration?>(
          stream: provider.sessionAudioPlayer.positionStream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Column(
                children: [
                  _durationLabels(
                      context,
                      provider.sessionAudioPlayer.duration?.inMilliseconds ?? 0,
                      snapshot.data?.inMilliseconds ?? 0),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 8,
                      trackShape: CustomTrackShape(),
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 5.0,
                      ),
                    ),
                    child: Slider(
                      min: 0.0,
                      activeColor: ColorConstants.walterWhite,
                      inactiveColor: ColorConstants.greyIsTheNewGrey,
                      max: provider.sessionAudioPlayer.duration?.inMilliseconds
                              .toDouble() ??
                          0,
                      value: snapshot.data?.inMilliseconds.toDouble() ?? 0,
                      onChanged: (value) {},
                      onChangeEnd: (value) {},
                    ),
                  ),
                ],
              );
            }
            return SizedBox();
          }),
    );
  }

  Transform _durationLabels(BuildContext context, int duration, int position) {
    return Transform.translate(
      offset: Offset(0, 25),
      child: Row(
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
      ),
    );
  }

  Text _durationLabel(
    BuildContext context,
    String label,
  ) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: ColorConstants.walterWhite, fontFamily: DmMono, fontSize: 14),
    );
  }

  String _calculateDuration(int duration) {
    return Duration(milliseconds: duration).toMinutesSeconds();
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
