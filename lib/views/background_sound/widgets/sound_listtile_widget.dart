import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SoundListTileWidget extends ConsumerWidget {
  const SoundListTileWidget({required this.sound}) : super();
  final BackgroundSoundsModel sound;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgSoundNotifierProvider = ref.watch(backgroundSoundsNotifierProvider);
    final audioPlayerNotifier = ref.watch(audioPlayerNotifierProvider);
    var isSelected = bgSoundNotifierProvider.selectedBgSound?.id == sound.id;

    return InkWell(
      onTap: () => _handleItemTap(
        ref,
        bgSoundNotifierProvider,
        audioPlayerNotifier,
        isSelected,
      ),
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
        border: Border.all(width: 2, color: ColorConstants.walterWhite),
      ),
      padding: EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 6,
        backgroundColor: isSelected
            ? ColorConstants.walterWhite
            : ColorConstants.transparent,
      ),
    );
  }

  void _handleItemTap(
    WidgetRef ref,
    BackgroundSoundsNotifier bgSoundNotifierProvider,
    AudioPlayerNotifier audioPlayerNotifier,
    bool isSelected,
  ) {
    if (sound.title == StringConstants.none) {
      bgSoundNotifierProvider.handleOnChangeSound(sound);
      audioPlayerNotifier.stopBackgroundSound();
    } else {
      bgSoundNotifierProvider.handleOnChangeSound(
        !isSelected
            ? sound
            : BackgroundSoundsModel(
                id: '0',
                title: StringConstants.none,
                duration: 0,
                path: '',
              ),
      );
      if (!isSelected) {
        audioPlayerNotifier.setBackgroundAudio(sound);
        audioPlayerNotifier.playBackgroundSound();
        _handleTrackEvent(ref, sound.id);
      } else {
        audioPlayerNotifier.stopBackgroundSound();
      }
    }
  }

  void _handleTrackEvent(WidgetRef ref, String bgSoundId) {
    var bgSelectedSoundModel =
        BgSoundSelectedModel(backgroundSoundId: bgSoundId);
    var event = EventsModel(
      name: EventTypes.backgroundSoundSelected,
      payload: bgSelectedSoundModel.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
