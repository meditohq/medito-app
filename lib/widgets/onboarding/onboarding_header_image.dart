import 'package:flutter/material.dart';

/// Full-bleed hero image at the top of an onboarding page.
///
/// Lives inside each page's own scroll view (rather than pinned above the
/// PageView) so it scrolls away with the content. Hidden in landscape and on
/// very short screens; shrinks on small screens so the content keeps room.
class OnboardingHeaderImage extends StatelessWidget {
  const OnboardingHeaderImage({super.key, required this.imagePath});

  final String imagePath;

  /// 0 when the image is hidden (landscape / very short screens).
  static double heightFor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    if (size.height <= 500 || mediaQuery.orientation == Orientation.landscape) {
      return 0;
    }
    // Small screens give up less of the viewport to the hero image.
    final fraction = size.height < 700 ? 0.2 : 0.3;
    return size.height * fraction;
  }

  @override
  Widget build(BuildContext context) {
    final height = heightFor(context);
    if (height == 0) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(imagePath, fit: BoxFit.cover),
    );
  }
}
