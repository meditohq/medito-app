import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayPauseButtonWidget extends ConsumerWidget {
  const PlayPauseButtonWidget({super.key, this.iconSize = 72});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(audioPlayerNotifierProvider);

    return StreamBuilder<bool>(
      stream: provider.playbackState.map((state) => state.playing).distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return InkWell(
          onTap: () => _handleTap(ref, playing),
          borderRadius: BorderRadius.circular(iconSize / 2),
          child: AnimatedCrossFade(
            firstChild: Icon(
              Icons.play_circle_fill,
              size: iconSize,
              color: ColorConstants.walterWhite,
            ),
            secondChild: Icon(
              Icons.pause_circle_outlined,
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
    final provider = ref.read(audioPlayerNotifierProvider);
    if (isPlaying) {
      provider.pause();
    } else {
      provider.play();
    }
  }
}
