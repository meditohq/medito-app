import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/player/audio_state_provider.dart';

import 'speed_sheet.dart';

/// Player action-bar label showing the current playback speed. Display only:
/// the action-bar slot owns the tap (opening [SpeedSheet]) so the whole
/// button area responds, not just the text. Reads the speed the engine
/// reports rather than local state.
class AudioSpeedWidget extends ConsumerWidget {
  const AudioSpeedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioStateProvider.select((s) => s.speed.speed));
    final isSelected = speed != 1.0;

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 48,
        alignment: Alignment.center,
        decoration: isSelected
            ? BoxDecoration(
                color: ColorConstants.graphite.withAlpha(200),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Text(
          formatSpeed(speed),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ColorConstants.white,
            fontFamily: googleSans,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
