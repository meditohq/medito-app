import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomActionBarItem {
  final Widget child;
  final VoidCallback onTap;

  const BottomActionBarItem({required this.child, required this.onTap});
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    this.leftItem,
    this.leftCenterItem,
    this.rightCenterItem,
    this.rightItem,
    this.height = 80.0,
    this.showBackground = false,
  });

  final BottomActionBarItem? leftItem;
  final BottomActionBarItem? leftCenterItem;
  final BottomActionBarItem? rightCenterItem;
  final BottomActionBarItem? rightItem;
  final double height;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final items = [leftItem, leftCenterItem, rightCenterItem, rightItem]
        .where((item) => item != null)
        .toList();

    return SafeArea(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: showBackground ? Colors.black.withOpacity(0.2) : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: items.length == 3
                ? MainAxisAlignment.spaceEvenly
                : MainAxisAlignment.spaceBetween,
            children: items.map((item) => _buildActionItem(item!)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(BottomActionBarItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: item.child is ConsumerWidget
            ? item.child
            : Consumer(builder: (_, __, ___) => item.child),
      ),
    );
  }
}