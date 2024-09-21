import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.actions,
    this.height = 80.0,
    this.showBackground = false,
  }) : assert(actions.length == 4, 'BottomActionBar must have exactly 4 actions');

  final List<Widget> actions;
  final double height;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: showBackground ? Colors.black.withOpacity(0.2) : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((widget) {
            return Expanded(
              child: Center(
                child: _wrapWithConsumer(widget),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _wrapWithConsumer(Widget widget) {
    return widget is ConsumerWidget ? widget : Consumer(builder: (_, __, ___) => widget);
  }
}