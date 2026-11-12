import 'package:flutter/material.dart';
import 'package:medito/constants/theme/medito_text.dart';

class HomeHeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeaderWidget({super.key, required this.greeting, this.color});

  final String greeting;

  /// Overrides the theme's onSurface, e.g. white over the hero image. When
  /// set, the text also gets a soft shadow so it survives busy artwork.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      greeting,
      style: context.text.display.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        shadows: color == null
            ? null
            : [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72.0);
}
