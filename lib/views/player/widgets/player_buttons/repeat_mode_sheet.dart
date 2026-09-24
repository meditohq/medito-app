import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/player/repeat_mode.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/player/repeat_state_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/widgets/radio_option_card.dart';

Future<void> showRepeatModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Three option cards plus the title overflow the default 9/16 cap.
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => const RepeatModeSheet(),
  );
}

/// Bottom sheet for picking the player's repeat mode. Spelling out what each
/// mode does (in particular that "forever" never reaches the end screen)
/// replaces the old tap-to-cycle icon, whose current state was hard to read.
class RepeatModeSheet extends ConsumerWidget {
  const RepeatModeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(repeatStateProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    void choose(RepeatMode mode) {
      if (mode != current) {
        ref.read(repeatStateProvider.notifier).setRepeatMode(mode);
        ref.read(playerProvider.notifier).setRepeatMode(mode);
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.playerRepeatChanged,
          parameters: {'repeat_mode': mode.name},
        );
      }
      Navigator.of(context).pop();
    }

    Widget option(RepeatMode mode, String title, String description) {
      return RadioOptionCard(
        title: title,
        description: description,
        selected: current == mode,
        onTap: () => choose(mode),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.repeat,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            option(
              RepeatMode.none,
              l10n.repeatModeOff,
              l10n.repeatModeOffDescription,
            ),
            const SizedBox(height: 12),
            option(
              RepeatMode.once,
              l10n.repeatModeOnce,
              l10n.repeatModeOnceDescription,
            ),
            const SizedBox(height: 12),
            option(
              RepeatMode.infinite,
              l10n.repeatModeForever,
              l10n.repeatModeForeverDescription,
            ),
          ],
        ),
      ),
    );
  }
}
