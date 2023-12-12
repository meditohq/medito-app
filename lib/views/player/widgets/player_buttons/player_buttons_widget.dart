import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_pause_button_widget.dart';

class PlayerButtonsWidget extends ConsumerWidget {
  const PlayerButtonsWidget({
    super.key,
    required this.trackModel,
    required this.file,
  });

  final TrackFilesModel file;
  final TrackModel trackModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(ref),
        SizedBox(width: 32),
        PlayPauseButtonWidget(),
        SizedBox(width: 32),
        _forwardButton(ref),
      ],
    );
  }

  IconButton _rewindButton(WidgetRef ref) {
    return IconButton(
      onPressed: () =>
          _handleForwardAndRewind(ref, SKIP_AUDIO.SKIP_BACKWARD_10),
      icon: Icon(
        Icons.replay_10_rounded,
        size: 40,
      ),
    );
  }

  IconButton _forwardButton(WidgetRef ref) {
    return IconButton(
      onPressed: () => _handleForwardAndRewind(ref, SKIP_AUDIO.SKIP_FORWARD_10),
      icon: Icon(
        Icons.forward_10_rounded,
        size: 40,
      ),
    );
  }

  void _handleForwardAndRewind(WidgetRef ref, SKIP_AUDIO skip) {
    var audioProvider = ref.read(audioPlayerNotifierProvider);
    final audioPositionAndPlayerState =
        ref.read(audioPositionAndPlayerStateProvider);

    var maxDuration = audioProvider.mediaItem.value?.duration ?? Duration();

    ref.read(
      skipAudioProvider(skip: skip),
    );

    audioProvider.handleFadeAtEnd(
      audioPositionAndPlayerState.value?.position ?? Duration(),
      maxDuration,
    );
  }
}
