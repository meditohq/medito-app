import 'package:flutter/material.dart';
import 'adaptive_content.dart';

/// Home keeps the user's vertical section order at every window width.
class AdaptiveHomeSections extends StatelessWidget {
  const AdaptiveHomeSections({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            AdaptiveContent(key: child.key, child: child),
        ],
      ),
    ),
  );
}
