import 'package:hugeicons/hugeicons.dart';
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
         HugeIcons.solidSharpPlayCircle,
          size: iconSize,
          color: ColorConstants.white,
        ),
        secondChild: Icon(
          HugeIcons.strokeSharpPauseCircle,
          size: iconSize,
          color: ColorConstants.white,
        ),
        crossFadeState:
            isPlaying ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 100),
      ),
    );
  }
}
