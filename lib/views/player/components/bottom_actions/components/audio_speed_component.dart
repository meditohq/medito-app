import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
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
      ref
          .read(audioPlayerNotifierProvider)
          .setSessionAudioSpeed(_provider.audioSpeedModel.speed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _provider = ref.watch(audioSpeedProvider);
    var audioSpeedModel = _provider.audioSpeedModel;

    return LabelsComponent(
      label: audioSpeedModel.label,
      bgColor: audioSpeedModel.label != StringConstants.X1
          ? ColorConstants.walterWhite
          : ColorConstants.greyIsTheNewGrey,
      textColor: audioSpeedModel.label != StringConstants.X1
          ? ColorConstants.greyIsTheNewGrey
          : ColorConstants.walterWhite,
      onTap: () {
        _provider.setAudioTrackSpeed();
        ref
            .read(audioPlayerNotifierProvider)
            .setSessionAudioSpeed(_provider.audioSpeedModel.speed);
      },
    );
  }
}
