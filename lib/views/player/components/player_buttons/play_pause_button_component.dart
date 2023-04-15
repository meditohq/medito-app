import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayPauseButtonComponent extends ConsumerWidget {
  const PlayPauseButtonComponent({super.key, this.iconSize = 72});
  final double iconSize;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(audioPlayerNotifierProvider);
    ref.watch(audioPlayPauseProvider);

    return StreamBuilder<bool>(
      stream: provider.playbackState.map((state) => state.playing).distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return InkWell(
          onTap: () => _handleTap(ref, playing),
          child: AnimatedCrossFade(
            firstChild: Icon(
              Icons.play_circle_fill,
              size: iconSize,
              color: ColorConstants.walterWhite,
            ),
            secondChild: Icon(
              Icons.pause_circle_filled,
              size: iconSize,
              color: ColorConstants.walterWhite,
            ),
            crossFadeState:
                playing ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 500),
          ),
        );
      },
    );
  }

  void _handleTap(WidgetRef ref, bool isPlaying) {
    if (isPlaying) {
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PAUSE;
    } else {
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PLAY;
    }
  }
}
