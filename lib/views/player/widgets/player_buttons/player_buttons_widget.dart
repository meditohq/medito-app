import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_pause_button_widget.dart';

class PlayerButtonsWidget extends ConsumerWidget {
  const PlayerButtonsWidget({
    required this.onSkip10SecondsBackward,
    required this.onSkip10SecondsForward,
    required this.isPlaying,
    super.key,
    required this.onPlayPause,
  });

  final Function() onSkip10SecondsBackward;
  final Function() onSkip10SecondsForward;
  final bool isPlaying;
  final Function() onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(),
        SizedBox(width: 32),
        PlayPauseButtonWidget(
          isPlaying: isPlaying,
          onPlayPause: onPlayPause,
        ),
        SizedBox(width: 32),
        _forwardButton(),
      ],
    );
  }

  IconButton _rewindButton() {
    return IconButton(
      onPressed: onSkip10SecondsBackward,
      icon: Icon(
        Icons.replay_10_rounded,
        size: 40,
      ),
    );
  }

  IconButton _forwardButton() {
    return IconButton(
      onPressed: onSkip10SecondsForward,
      icon: Icon(
        Icons.forward_10_rounded,
        size: 40,
      ),
    );
  }
}
