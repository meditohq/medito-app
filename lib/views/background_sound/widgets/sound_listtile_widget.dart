import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/medito_icon.dart';

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

    return InkWell(
      onTap: () => _handleItemTap(ref, context, hasFailed: hasFailed),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Row(
          children: [
            _radioButton(isSelected, context),
            width16,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // The repository builds the "None" row with a hardcoded
                    // English title, to be localised here.
                    sound.id == kNoneBackgroundSoundId
                        ? AppLocalizations.of(context)!.none
                        : sound.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: dmSans,
                      fontSize: 16,
                    ),
                  ),
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
          fontFamily: dmSans,
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
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
      ),
    );
  }

  Container _radioButton(bool isSelected, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          width: 2,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 6,
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : ColorConstants.transparent,
      ),
    );
  }

  void _handleItemTap(
    WidgetRef ref,
    BuildContext context, {
    required bool hasFailed,
  }) {
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
