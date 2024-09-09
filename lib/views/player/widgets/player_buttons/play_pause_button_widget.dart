import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayPauseButtonWidget extends ConsumerWidget {
  const PlayPauseButtonWidget({
    super.key,
    this.iconSize = 72,
    required this.isPlaying,
    required this.onPlayPause,
  });

  final double iconSize;
  final bool isPlaying;
  final Function() onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return InkWell(
      onTap: onPlayPause,
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
        isPlaying ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: Duration(milliseconds: 250),
      ),
    );
  }

}
