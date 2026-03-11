import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

class AnimatedFavouriteIcon extends StatelessWidget {
  const AnimatedFavouriteIcon({
    super.key,
    required this.isFavorite,
    required this.color,
  });

  final bool isFavorite;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final assetName = isFavorite ? MeditoIcons.starSolid : MeditoIcons.star;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scaleAnimation = Tween<double>(
          begin: 0.72,
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      child: MeditoIcon(
        key: ValueKey(assetName),
        assetName: assetName,
        color: color,
      ),
    );
  }
}
