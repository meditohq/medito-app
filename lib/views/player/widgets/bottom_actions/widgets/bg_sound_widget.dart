import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../../../../background_sound/background_sound_view.dart';

class BgSoundWidget extends ConsumerStatefulWidget {
  const BgSoundWidget({super.key, required this.isBackgroundSoundSelected});

  final bool isBackgroundSoundSelected;

  @override
  ConsumerState<BgSoundWidget> createState() => _BgSoundWidgetState();
}

class _BgSoundWidgetState extends ConsumerState<BgSoundWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isBackgroundSoundSelected) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BgSoundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBackgroundSoundSelected &&
        !oldWidget.isBackgroundSoundSelected) {
      _animationController.repeat();
    } else if (!widget.isBackgroundSoundSelected &&
        oldWidget.isBackgroundSoundSelected) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.isBackgroundSoundSelected
          ? BoxDecoration(
              color: ColorConstants.graphite.withAlpha(200),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BackgroundSoundView(),
            ),
          );
        },
        tooltip: AppLocalizations.of(context)!.backgroundSounds,
        icon: widget.isBackgroundSoundSelected
            ? _spinningIcon()
            : MeditoIcon(
                assetName: MeditoIcons.musicNote,
                color: Colors.white,
                size: 23,
              ),
      ),
    );
  }

  Widget _spinningIcon() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animationController.value * 2 * 3.1415926535897932,
          child: MeditoIcon(
            assetName: MeditoIcons.compactDiscSolid,
            color: ColorConstants.white,
          ),
        );
      },
    );
  }
}
