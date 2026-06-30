import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/background_sounds/background_sounds_notifier.dart';

class SoundListTileWidget extends ConsumerWidget {
  const SoundListTileWidget({super.key, required this.sound});
  final BackgroundSoundsModel sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundState = ref.watch(backgroundSoundsNotifierProvider);
    var selectedSoundId = bgSoundState.selectedBgSound?.id ?? '0';
    var isDownloading = bgSoundState.downloadingBgSound?.id == sound.id;
    var isSelected = selectedSoundId == sound.id;

    return InkWell(
      onTap: () => _handleItemTap(ref, context),
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
            Text(
              sound.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: dmSans,
                fontSize: 16,
              ),
            ),
            isDownloading ? _loadingSpinner(context) : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Expanded _loadingSpinner(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
          ],
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

  void _handleItemTap(WidgetRef ref, BuildContext context) {
    final notifier = ref.read(backgroundSoundsNotifierProvider.notifier);
    if (sound.title == AppLocalizations.of(context)!.none) {
      notifier.stopBackgroundSound();
    }
    notifier.handleOnChangeSound(sound);
  }
}
