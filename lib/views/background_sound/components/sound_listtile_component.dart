import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SoundListTileComponent extends ConsumerWidget {
  const SoundListTileComponent({required this.sound}) : super();
  final BackgroundSoundsModel sound;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundNotifierProvider = ref.watch(backgroundSoundsNotifierProvider);
    final audioPlayerNotifier = ref.watch(audioPlayerNotifierProvider);
    var isSelected = bgSoundNotifierProvider.selectedBgSound?.id == sound.id;
    return InkWell(
      onTap: () => _handleItemTap(
          bgSoundNotifierProvider, audioPlayerNotifier, isSelected),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 0.9, color: ColorConstants.softGrey),
          ),
        ),
        constraints: BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Row(
          children: [
            _radioButton(isSelected),
            width16,
            Text(
              sound.title,
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: DmSans,
                    fontSize: 16,
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
          border: Border.all(width: 2, color: ColorConstants.walterWhite)),
      padding: EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 6,
        backgroundColor: isSelected
            ? ColorConstants.walterWhite
            : ColorConstants.transparent,
      ),
    );
  }

  void _handleItemTap(BackgroundSoundsNotifier bgSoundNotifierProvider,
      AudioPlayerNotifier audioPlayerNotifier, bool isSelected) {
    if (sound.title == StringConstants.NONE) {
      bgSoundNotifierProvider.handleOnChangeSound(sound);
      audioPlayerNotifier.stopBackgroundSound();
    } else {
      bgSoundNotifierProvider.handleOnChangeSound(
        !isSelected
            ? sound
            : BackgroundSoundsModel(
                id: 0, title: StringConstants.NONE, duration: 0, path: ''),
      );
      if (!isSelected) {
        audioPlayerNotifier.setBackgroundAudio(sound);
        audioPlayerNotifier.playBackgroundSound();
      } else {
        audioPlayerNotifier.stopBackgroundSound();
      }
    }
  }
}
