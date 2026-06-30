import 'package:flutter/material.dart';

enum BottomActionBarLayout {
  homePage, // For bottom nav - all items evenly spaced
  evenlySpaced, //  4 all items evenly spaced
  edgeAligned, // For player view - outer items at edges, inner items evenly spaced
  compactRight, // For track view - items at edges with last two grouped
}

class BottomActionBarItem {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const BottomActionBarItem({
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });
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

    return IconButton(
      onPressed: item.onTap,
      tooltip: item.semanticLabel,
      icon: item.child,
    );
  }

  List<Widget> _buildLayoutChildren() {
    switch (layout) {
      case BottomActionBarLayout.compactRight:
        return [
          _buildItem(leftItem),
          const Spacer(),
          if (rightCenterItem != null) _buildItem(rightCenterItem),
          if (leftCenterItem != null) _buildItem(leftCenterItem),
          if (rightItem != null) _buildItem(rightItem),
        ];

      case BottomActionBarLayout.homePage:
        return [
          _buildItem(leftItem),
          _buildItem(leftCenterItem),
          // _buildItem(rightCenterItem),
          _buildItem(rightItem),
        ];

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
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment:
              layout == BottomActionBarLayout.evenlySpaced ||
                  layout == BottomActionBarLayout.homePage
              ? MainAxisAlignment.spaceEvenly
              : MainAxisAlignment.start,
          children: _buildLayoutChildren(),
        ),
      ),
    );
  }
}
