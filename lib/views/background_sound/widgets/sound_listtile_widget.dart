import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/background_sounds/background_sounds_notifier.dart';

class SoundListTileWidget extends ConsumerWidget {
  const SoundListTileWidget({super.key, required this.sound});
  final BackgroundSoundsModel sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundNotifierProvider = ref.watch(backgroundSoundsNotifierProvider);
    var selectedSoundId = bgSoundNotifierProvider.selectedBgSound?.id ?? '0';
    var isDownloading =
        bgSoundNotifierProvider.downloadingBgSound?.id == sound.id;
    var isSelected = selectedSoundId == sound.id;

    return InkWell(
      onTap: () => _handleItemTap(
        bgSoundNotifierProvider,
      ),
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
            _radioButton(isSelected),
            width16,
            Text(
              sound.title,
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                    color: ColorConstants.white,
                    fontFamily: DmSans,
                    fontSize: 16,
                  ),
            ),
            isDownloading ? _loadingSpinner() : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Expanded _loadingSpinner() {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorConstants.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Container _radioButton(bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(width: 2, color: ColorConstants.white),
      ),
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 6,
        backgroundColor:
            isSelected ? ColorConstants.white : ColorConstants.transparent,
      ),
    );
  }

  void _handleItemTap(
    BackgroundSoundsNotifier bgSoundNotifierProvider,
  ) {
    if (sound.title == StringConstants.none) {
      bgSoundNotifierProvider.stopBackgroundSound();
    }
    bgSoundNotifierProvider.handleOnChangeSound(sound);
  }
}
