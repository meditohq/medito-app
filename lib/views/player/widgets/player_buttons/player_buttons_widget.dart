import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../providers/player/repeat_state_provider.dart';
import '../../../../src/audio_pigeon.g.dart';
import 'play_pause_button_widget.dart';

class PlayerButtonsWidget extends ConsumerWidget {
  const PlayerButtonsWidget({
    required this.onSkip10SecondsBackward,
    required this.onSkip10SecondsForward,
    required this.isPlaying,
    super.key,
    required this.onPlayPause,
    required this.onRepeat,
    this.isPortrait = true,
  });

  final Function() onSkip10SecondsBackward;
  final Function() onSkip10SecondsForward;
  final bool isPlaying;
  final Function() onPlayPause;
  final Function() onRepeat;
  final bool isPortrait;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeatMode = ref.watch(repeatStateProvider);

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _rewindButton(),
              const SizedBox(width: 32),
              _repeatButton(repeatMode),
              const SizedBox(width: 32),
              _forwardButton(),
            ],
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _rewindButton(),
          const SizedBox(width: 32),
          PlayPauseButtonWidget(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
          ),
          const SizedBox(width: 32),
          _forwardButton(),
          const SizedBox(width: 32),
          _repeatButton(repeatMode),
        ],
      );
    }
  }

  IconButton _rewindButton() {
    return IconButton(
      onPressed: onSkip10SecondsBackward,
      icon: Icon(
        HugeIcons.strokeStandardGoBackward10Sec,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  IconButton _forwardButton() {
    return IconButton(
      onPressed: onSkip10SecondsForward,
      icon: Icon(
        HugeIcons.strokeStandardGoForward10Sec,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  IconButton _repeatButton(RepeatMode repeatMode) {
    IconData iconData;
    Color? iconColor;

    switch (repeatMode) {
      case RepeatMode.none:
        iconData = HugeIcons.solidSharpRepeat;
        iconColor = Colors.white;
        break;
      case RepeatMode.infinite:
        iconData = HugeIcons.solidStandardRepeatOne01;
        iconColor = Colors.white;
        break;
    }

    return IconButton(
      onPressed: onRepeat,
      icon: Icon(
        iconData,
        size: 32,
        color: iconColor,
      ),
    );
  }
}
