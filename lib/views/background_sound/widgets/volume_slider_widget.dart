import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:medito/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/background_sounds/background_sounds_notifier.dart';
import 'background_sound_volume_track_shape_widget.dart';

class VolumeSliderWidget extends ConsumerWidget {
  const VolumeSliderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundState = ref.watch(backgroundSoundsNotifierProvider);
    final currentVolume = bgSoundState.volume;
    // With no background sound there is nothing to adjust, so the bar is
    // dimmed and inert until a sound is picked.
    final hasSound =
        (bgSoundState.selectedBgSound?.id ?? kNoneBackgroundSoundId) !=
        kNoneBackgroundSoundId;

    final slider = SliderTheme(
      data: SliderThemeData(
        trackShape: BackgroundSoundVolumeTrackShapeWidget(
          leadingTitle: AppLocalizations.of(context)!.volume,
          tralingText: '${currentVolume.toString().split('.').first}%',
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0.0),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0.0),
        trackHeight: 72,
      ),
      child: Slider(
        value: currentVolume.clamp(0, 100),
        min: 0,
        max: 100,
        divisions: 100,
        activeColor: context.brandPurple,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        onChanged: (double newValue) {
          ref
              .read(backgroundSoundsNotifierProvider.notifier)
              .handleOnChangeVolume(newValue);
        },
        onChangeEnd: (double newValue) {
          FirebaseAnalyticsService().logEvent(
            name: AnalyticsEventConstants.backgroundSoundVolumeChanged,
            parameters: {'volume': newValue.round()},
          );
        },
        semanticFormatterCallback: (double newValue) {
          return '${newValue.round()} ';
        },
      ),
    );

    return AnimatedOpacity(
      opacity: hasSound ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(ignoring: !hasSound, child: slider),
    );
  }
}
