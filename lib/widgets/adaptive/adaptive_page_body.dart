import 'package:flutter/material.dart';
import 'adaptive_content.dart';

/// Constrains reading and control surfaces while preserving their scroll view.
class AdaptivePageBody extends StatelessWidget {
  const AdaptivePageBody({super.key, required this.child, this.maxWidth = 960});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AdaptiveContent(child: child),
    ),
  );
}
