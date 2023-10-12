import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'labels_widget.dart';

class AudioSpeedWidget extends ConsumerStatefulWidget {
  const AudioSpeedWidget({super.key});

  @override
  ConsumerState<AudioSpeedWidget> createState() => _AudioSpeedComponentState();
}

class _AudioSpeedComponentState extends ConsumerState<AudioSpeedWidget> {
  @override
  void initState() {
    super.initState();
    final _provider = ref.read(audioSpeedProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.getAudioTrackSpeedFromPref();
      ref
          .read(audioPlayerNotifierProvider)
          .setTrackAudioSpeed(_provider.audioSpeedModel.speed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _provider = ref.watch(audioSpeedProvider);
    var audioSpeedModel = _provider.audioSpeedModel;

    return LabelsWidget(
      label: audioSpeedModel.label,
      bgColor: audioSpeedModel.label != StringConstants.x1
          ? ColorConstants.walterWhite
          : ColorConstants.greyIsTheNewGrey,
      textColor: audioSpeedModel.label != StringConstants.x1
          ? ColorConstants.greyIsTheNewGrey
          : ColorConstants.walterWhite,
      onTap: () {
        _provider.setAudioTrackSpeed();
        ref
            .read(audioPlayerNotifierProvider)
            .setTrackAudioSpeed(_provider.audioSpeedModel.speed);
      },
    );
  }
}
