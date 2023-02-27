import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:Medito/view_model/background_sounds/background_sounds_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/sound_listtile_component.dart';
import 'components/volume_slider_component.dart';

class BackgroundSoundView extends ConsumerStatefulWidget {
  const BackgroundSoundView({Key? key}) : super(key: key);

  @override
  ConsumerState<BackgroundSoundView> createState() =>
      _BackgroundSoundViewState();
}

class _BackgroundSoundViewState extends ConsumerState<BackgroundSoundView> {
  @override
  void initState() {
    super.initState();
    setInitStateValues();
  }

  void setInitStateValues() {
    final _provider = ref.read(backgroundSoundsNotifierProvider);
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);

    _provider.getBackgroundSoundFromPref().then((_) {
      if (_provider.selectedBgSound != null) {
        _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        _audioPlayerNotifier.playBackgroundSound();
      }
    });
    _provider.getVolumeFromPref().then((_) {
      _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
    });
  }

  @override
  Widget build(BuildContext context) {
    var backgroundSounds = ref.watch(backgroundSoundsProvider);
    return Scaffold(
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () async => await ref.refresh(backgroundSoundsProvider),
        ),
        loading: () => BackgroundSoundsShimmerComponent(),
      ),
    );
  }

  CollapsibleHeaderComponent _mainContent(
      BuildContext context, List<BackgroundSoundsModel> data, WidgetRef ref) {
    return CollapsibleHeaderComponent(
      title: StringConstants.BACKGROUND_SOUNDS,
      leadingIconBgColor: ColorConstants.walterWhite,
      leadingIconColor: ColorConstants.almostBlack,
      headerHeight: 130,
      children: [
        VolumeSliderComponent(),
        for (int i = 0; i < data.length; i++)
          SoundListTileComponent(sound: data[i])
      ],
    );
  }
}
