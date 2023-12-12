import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_sound_volume_track_shape_widget.dart';

class VolumeSliderWidget extends ConsumerWidget {
  const VolumeSliderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundNotifierProvider = ref.watch(backgroundSoundsNotifierProvider);
    final audioPlayerNotifier = ref.watch(audioPlayerNotifierProvider);
    var currentVolume = bgSoundNotifierProvider.volume;

    return SliderTheme(
      data: SliderThemeData(
        trackShape: BackgroundSoundVolumeTrackShapeWidget(
          leadingTitle: StringConstants.volume,
          tralingText: currentVolume.toString().split('.').first + '%',
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
        trackHeight: 72,
      ),
      child: Slider(
        value: currentVolume,
        min: 0,
        max: 100,
        divisions: 100,
        activeColor: ColorConstants.lightPurple,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        onChanged: (double newValue) {
          bgSoundNotifierProvider.handleOnChangeVolume(newValue);
          audioPlayerNotifier.setBackgroundSoundVolume(newValue);
        },
        semanticFormatterCallback: (double newValue) {
          return '${newValue.round()} ';
        },
      ),
    );
  }
}
