import 'package:flutter/material.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.actions,
    this.height = 56.0, // Default height
  });

  final List<Widget> actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((widget) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: widget,
            );
          }).toList(),
        ),
      ),
    );
  }
}
