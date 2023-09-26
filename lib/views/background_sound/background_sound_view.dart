import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/sound_listtile_widget.dart';
import 'widgets/volume_slider_widget.dart';

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
    if (!_audioPlayerNotifier.trackAudioPlayer.playerState.playing) {
      _audioPlayerNotifier.stopBackgroundSound();
    }
    super.deactivate();
  }

  void setInitStateValues() {
    final _provider = ref.read(backgroundSoundsNotifierProvider);
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    if (!_audioPlayerNotifier.backgroundSoundAudioPlayer.playerState.playing) {
      _provider.getBackgroundSoundFromPref();
      if (_provider.selectedBgSound != null &&
          _provider.selectedBgSound?.title != StringConstants.none) {
        _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        _audioPlayerNotifier.playBackgroundSound();
      }

      _provider.getVolumeFromPref();
      _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
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
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(backgroundSoundsProvider),
        ),
        loading: () => BackgroundSoundsShimmerWidget(),
      ),
    );
  }

  RefreshIndicator _mainContent(
    List<BackgroundSoundsModel> data,
  ) {
    return RefreshIndicator(
      onRefresh: () async => await ref.refresh(backgroundSoundsProvider),
      child: CollapsibleHeaderWidget(
        title: StringConstants.backgroundSounds,
        leadingIconBgColor: ColorConstants.walterWhite,
        leadingIconColor: ColorConstants.almostBlack,
        headerHeight: 130,
        children: [
          VolumeSliderWidget(),
          SoundListTileWidget(
            sound: BackgroundSoundsModel(
              id: '0',
              title: StringConstants.none,
              duration: 0,
              path: '',
            ),
          ),
          Column(
            children: data
                .map((e) => SoundListTileWidget(
                      sound: e,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
