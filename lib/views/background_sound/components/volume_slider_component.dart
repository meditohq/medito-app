import 'package:Medito/constants/constants.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'custom_track_shape_component.dart';

class VolumeSliderComponent extends ConsumerWidget {
  const VolumeSliderComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundNotifierProvider = ref.watch(backgroundSoundsNotifierProvider);
    final audioPlayerNotifier = ref.watch(audioPlayerNotifierProvider);
    var currentVolume = bgSoundNotifierProvider.volume;
    return SliderTheme(
      data: SliderThemeData(
          trackShape: CustomTrackShapeComponent(
              leadingTitle: StringConstants.VOLUME,
              tralingText: currentVolume.toString().split('.').first + '%'),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
          trackHeight: 72),
      child: Slider(
        value: currentVolume,
        min: 0,
        max: 100,
        divisions: 100,
        activeColor: ColorConstants.purple,
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
