import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    Key? key,
    required this.actions,
    this.height = 80.0,
    this.showBackground = false,
  }) : super(key: key);

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
              child: _wrapWithConsumer(widget),
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