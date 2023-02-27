import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:Medito/view_model/player/audio_speed_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'labels_component.dart';

class AudioSpeedComponent extends ConsumerStatefulWidget {
  const AudioSpeedComponent({super.key});

  @override
  ConsumerState<AudioSpeedComponent> createState() =>
      _AudioSpeedComponentState();
}

class _AudioSpeedComponentState extends ConsumerState<AudioSpeedComponent> {
  @override
  void initState() {
    super.initState();
    final _provider = ref.read(audioSpeedProvider);
    _provider.getAudioTrackSpeedFromPref().then((_) {
      ref.read(audioPlayerNotifierProvider).setSessionAudioSpeed(_provider.audioSpeedModel.speed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _provider = ref.watch(audioSpeedProvider);
    var audioSpeedModel = _provider.audioSpeedModel;
    return LabelsComponent(
      label: audioSpeedModel.label,
      onTap: () {
        _provider.setAudioTrackSpeed();
        ref
            .read(audioPlayerNotifierProvider)
            .setSessionAudioSpeed(_provider.audioSpeedModel.speed);
      },
    );
  }
}
