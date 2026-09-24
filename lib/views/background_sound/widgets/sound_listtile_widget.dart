import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/radio_option_card.dart';

import '../../../providers/background_sounds/background_sounds_notifier.dart';

class SoundListTileWidget extends ConsumerWidget {
  const SoundListTileWidget({super.key, required this.sound});
  final BackgroundSoundsModel sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundState = ref.watch(backgroundSoundsNotifierProvider);
    var selectedSoundId =
        bgSoundState.selectedBgSound?.id ?? kNoneBackgroundSoundId;
    var isDownloading = bgSoundState.downloadingBgSound?.id == sound.id;
    var isSelected = selectedSoundId == sound.id;
    var hasFailed = bgSoundState.failedBgSound?.id == sound.id;

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // Styled like the settings sheets (same radio dot, type and 16pt margins)
    // but as plain rows rather than bordered cards: the list is long and
    // cards would push most of it below the fold.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () => _handleItemTap(ref, context, hasFailed: hasFailed),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                RadioDot(selected: isSelected, accent: context.brandPurple),
                const SizedBox(width: padding12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The repository builds the "None" row with a
                        // hardcoded English title, to be localised here.
                        sound.id == kNoneBackgroundSoundId
                            ? AppLocalizations.of(context)!.none
                            : sound.id == kSessionBellsId
                            ? AppLocalizations.of(context)!.sessionBells
                            : sound.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      if (sound.id == kSessionBellsId) ...[
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.sessionBellsDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (hasFailed) _failureMessage(context),
                    ],
                  ),
                ),
                if (isDownloading)
                  _loadingSpinner(context)
                else if (hasFailed)
                  _retryIcon(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shown when a download or playback attempt failed. Tapping the row retries
  /// — previously a failure was completely silent, leaving the row looking
  /// selected with nothing playing and no way to recover.
  Widget _failureMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Text(
        AppLocalizations.of(context)!.backgroundSoundDownloadFailed,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: googleSans,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Widget _retryIcon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MeditoIcon(
        assetName: MeditoIcons.downloadCircle,
        color: Theme.of(context).colorScheme.error,
        size: 20,
      ),
    );
  }

  Widget _loadingSpinner(BuildContext context) {
    // Not Expanded: the title column takes the free space now, so this only
    // needs to sit at the trailing edge like the retry icon.
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _handleItemTap(
    WidgetRef ref,
    BuildContext context, {
    required bool hasFailed,
  }) {
    FirebaseAnalyticsService().logEvent(
      name: hasFailed
          ? AnalyticsEventConstants.backgroundSoundRetryTapped
          : AnalyticsEventConstants.backgroundSoundSelected,
      parameters: {'sound_id': sound.id, 'sound_title': sound.title},
    );
    final notifier = ref.read(backgroundSoundsNotifierProvider.notifier);

    // Retrying discards whatever is cached for the sound; a plain re-select
    // would happily reuse a corrupt file and fail again.
    if (hasFailed) {
      notifier.retryDownload(sound);

      return;
    }

    // No special-casing for "None" here: the notifier stops playback for it,
    // keyed on the id. Comparing the (English) title to the localised string
    // meant non-English users could never switch background sound off.
    notifier.handleOnChangeSound(sound);
  }
}
