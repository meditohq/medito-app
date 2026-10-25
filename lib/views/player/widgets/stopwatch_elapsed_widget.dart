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
    final l10n = AppLocalizations.of(context)!;
    final elapsed = Duration(milliseconds: positionMs);
    // One label ("12 minutes 34 seconds elapsed"), not the clock and caption
    // apart; a clock like "12:34" can be read as a time of day. Not a live
    // region: it changes every second.
    return Semantics(
      label: '${spokenDuration(elapsed, l10n)} ${l10n.timerElapsed}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTimerClock(elapsed),
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
            l10n.timerElapsed,
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
