import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/timer/timer_format.dart';

/// Takes the seek bar's place in a stopwatch session: there is no length to
/// seek through, only the time sat so far.
class StopwatchElapsedWidget extends ConsumerWidget {
  const StopwatchElapsedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionMs = ref.watch(audioStateProvider.select((s) => s.position));
    final textTheme = Theme.of(context).textTheme;
    // One announcement ("12:34 elapsed"), not the time and caption apart.
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTimerClock(Duration(milliseconds: positionMs)),
            style: textTheme.displayMedium?.copyWith(
              color: ColorConstants.white,
              fontFamily: googleSans,
              fontSize: 44,
              fontWeight: FontWeight.w300,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.timerElapsed,
            style: textTheme.titleSmall?.copyWith(
              color: ColorConstants.white.withValues(alpha: 0.7),
              fontFamily: googleSans,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
