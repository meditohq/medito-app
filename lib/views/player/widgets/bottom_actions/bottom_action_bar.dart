import 'package:flutter/material.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.actions,
    this.height = 80.0,
    this.showBackground = false,
  });

  final List<Widget> actions;
  final double height;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: showBackground ? Colors.black.withOpacity(0.2) : Colors.transparent,
      ),
      child: SafeArea(
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