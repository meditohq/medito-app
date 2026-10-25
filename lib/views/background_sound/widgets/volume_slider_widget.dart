import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/background_sounds/background_sounds_notifier.dart';
import 'background_sound_volume_track_shape_widget.dart';

class VolumeSliderWidget extends ConsumerWidget {
  const VolumeSliderWidget({super.key});

  static const _a11yStep = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundState = ref.watch(backgroundSoundsNotifierProvider);
    final currentVolume = bgSoundState.volume;
    // With nothing playing over the session there is nothing to adjust, so
    // the bar is dimmed and inert. Bells use this volume too.
    final hasSound = bgSoundState.hasAnySound;

    void setVolume(double volume) => ref
        .read(backgroundSoundsNotifierProvider.notifier)
        .handleOnChangeVolume(volume);
    void logVolume(double volume) => FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.backgroundSoundVolumeChanged,
      parameters: {'volume': volume.round()},
    );

    final l10n = AppLocalizations.of(context)!;
    final volume = currentVolume.clamp(0.0, 100.0).toDouble();
    String percent(double v) => '${v.round()}%';
    // A screen-reader swipe steps 10%; the slider's own step was 1%.
    double stepped(double by) => (volume + by).clamp(0.0, 100.0).toDouble();
    void adjust(double by) {
      setVolume(stepped(by));
      logVolume(stepped(by));
    }

    final slider = SliderTheme(
      data: SliderThemeData(
        trackShape: BackgroundSoundVolumeTrackShapeWidget(
          leadingTitle: l10n.volume,
          tralingText: '${currentVolume.toString().split('.').first}%',
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0.0),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0.0),
        trackHeight: 72,
      ),
      child: Slider(
        value: volume,
        min: 0,
        max: 100,
        divisions: 100,
        activeColor: context.brandAccent,
        inactiveColor: ColorConstants.greyIsTheNewGrey,
        onChanged: setVolume,
        onChangeEnd: logVolume,
      ),
    );

    // The title and percentage are painted by the track shape, so screen
    // readers heard only "45, slider". Name it here, and say it's disabled
    // when there's no sound (IgnorePointer alone still read as adjustable).
    return Semantics(
      slider: true,
      enabled: hasSound,
      label: l10n.volume,
      value: percent(volume),
      increasedValue: hasSound ? percent(stepped(_a11yStep)) : null,
      decreasedValue: hasSound ? percent(stepped(-_a11yStep)) : null,
      onIncrease: hasSound ? () => adjust(_a11yStep) : null,
      onDecrease: hasSound ? () => adjust(-_a11yStep) : null,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: hasSound ? 1 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(ignoring: !hasSound, child: slider),
        ),
      ),
    );
  }
}
