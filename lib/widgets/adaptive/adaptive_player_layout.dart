import 'package:flutter/material.dart';

/// Repositions the existing title and transport without adding player content.
class AdaptivePlayerLayout extends StatelessWidget {
  const AdaptivePlayerLayout({
    super.key,
    required this.expanded,
    required this.heading,
    required this.controls,
  });

  final bool expanded;
  final Widget heading;
  final Widget controls;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1040),
    child: expanded
        ? Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 40),
              Expanded(child: controls),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [heading, const SizedBox(height: 32), controls],
          ),
  );
}
