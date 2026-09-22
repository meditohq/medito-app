import 'package:flutter/material.dart';

/// Gives older screen-width-based widgets the width of their actual pane.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(constraints.maxWidth, MediaQuery.sizeOf(context).height),
      ),
      child: child,
    ),
  );
}
