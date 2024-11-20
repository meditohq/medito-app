import 'package:flutter/material.dart';

enum BottomActionBarLayout {
  evenlySpaced,     // For bottom nav - all items evenly spaced
  edgeAligned,      // For player view - outer items at edges, inner items evenly spaced
  compactRight,     // For track view - items at edges with last two grouped
}

class BottomActionBarItem {
  final Widget child;
  final VoidCallback? onTap;

  const BottomActionBarItem({required this.child, required this.onTap});
}

class BottomActionBar extends StatelessWidget {
  final BottomActionBarItem? leftItem;
  final BottomActionBarItem? leftCenterItem;
  final BottomActionBarItem? rightCenterItem;
  final BottomActionBarItem? rightItem;
  final BottomActionBarLayout layout;

  const BottomActionBar({
    super.key,
    this.leftItem,
    this.leftCenterItem,
    this.rightCenterItem,
    this.rightItem,
    this.layout = BottomActionBarLayout.compactRight,
  });

  Widget _buildItem(BottomActionBarItem? item) {
    if (item == null) {
      return const SizedBox(width: 48);
    }

    return GestureDetector(
      onTap: item.onTap,
      child: item.child,
    );
  }

  List<Widget> _buildLayoutChildren() {
    switch (layout) {
      case BottomActionBarLayout.evenlySpaced:
        return [
          _buildItem(leftItem),
          _buildItem(leftCenterItem),
          _buildItem(rightCenterItem),
          if (rightItem != null) _buildItem(rightItem),
        ];

      case BottomActionBarLayout.edgeAligned:
        return [
          _buildItem(leftItem),
          const Spacer(),
          _buildItem(leftCenterItem),
          const Spacer(),
          _buildItem(rightCenterItem),
          const Spacer(),
          _buildItem(rightItem),
          SizedBox.square(dimension: 20,)
        ];

      case BottomActionBarLayout.compactRight:
        if (rightItem != null) {
          return [
            _buildItem(leftItem),
            const Spacer(),
            _buildItem(rightCenterItem),
            const SizedBox(width: 16),
            _buildItem(rightItem),
          ];
        } else {
          return [
            _buildItem(leftItem),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _buildItem(rightCenterItem),
            ),
          ];
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        
        child: Row(
          mainAxisAlignment: layout == BottomActionBarLayout.evenlySpaced 
              ? MainAxisAlignment.spaceEvenly 
              : MainAxisAlignment.start,
          children: _buildLayoutChildren(),
        ),
      ),
    );
  }
}
