import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
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

  @override
  void deactivate() {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    if (!_audioPlayerNotifier.sessionAudioPlayer.playerState.playing) {
      _audioPlayerNotifier.stopBackgroundSound();
    }
    super.deactivate();
  }

  void setInitStateValues() {
    final _provider = ref.read(backgroundSoundsNotifierProvider);
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    if (!_audioPlayerNotifier.backgroundSoundAudioPlayer.playerState.playing) {
      _provider.getBackgroundSoundFromPref().then((_) {
        if (_provider.selectedBgSound != null &&
            _provider.selectedBgSound?.title != StringConstants.NONE) {
          _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
          _audioPlayerNotifier.playBackgroundSound();
        }
      });
      _provider.getVolumeFromPref().then((_) {
        _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var backgroundSounds = ref.watch(backgroundSoundsProvider);

    return Scaffold(
      body: backgroundSounds.when(
        skipLoadingOnRefresh: false,
        data: (data) => _mainContent(
          data,
        ),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () => ref.refresh(backgroundSoundsProvider),
        ),
        loading: () => BackgroundSoundsShimmerComponent(),
      ),
    );
  }

  CollapsibleHeaderComponent _mainContent(
    List<BackgroundSoundsModel> data,
  ) {
    return CollapsibleHeaderComponent(
      title: StringConstants.BACKGROUND_SOUNDS,
      leadingIconBgColor: ColorConstants.walterWhite,
      leadingIconColor: ColorConstants.almostBlack,
      headerHeight: 130,
      children: [
        VolumeSliderComponent(),
        SoundListTileComponent(
          sound: BackgroundSoundsModel(
            id: 0,
            title: StringConstants.NONE,
            duration: 0,
            path: '',
          ),
        ),
        for (int i = 0; i < data.length; i++)
          SoundListTileComponent(
            sound: data[i],
          ),
      ],
    );
  }
}
