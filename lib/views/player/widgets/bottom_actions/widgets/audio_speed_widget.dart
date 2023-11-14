import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    var textColor = audioSpeedModel.label != StringConstants.x1
        ? ColorConstants.lightPurple
        : ColorConstants.walterWhite;

    return GestureDetector(
      onTap: () {
        _provider.setAudioTrackSpeed();
        ref
            .read(audioPlayerNotifierProvider)
            .setTrackAudioSpeed(_provider.audioSpeedModel.speed);
      },
      child: Text(
        audioSpeedModel.label,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: textColor, fontFamily: DmMono, fontSize: 18),
        textAlign: TextAlign.center,
      ),
    );
  }
}
