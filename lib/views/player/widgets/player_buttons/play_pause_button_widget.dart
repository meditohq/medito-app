import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: isPlaying ? l10n.pause : l10n.play,
      button: true,
      child: InkWell(
        onTap: onPlayPause,
        borderRadius: BorderRadius.circular(iconSize / 2),
        child: ExcludeSemantics(
          child: AnimatedCrossFade(
            firstChild: MeditoIcon(
              assetName: MeditoIcons.playSolid,
              size: iconSize,
              color: ColorConstants.white,
            ),
            secondChild: MeditoIcon(
              assetName: MeditoIcons.pause,
              size: iconSize,
              color: ColorConstants.white,
            ),
            crossFadeState: isPlaying
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );
  }
}
