import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'bottom_action_bar.dart';

class SingleBackButtonActionBar extends StatelessWidget {
  const SingleBackButtonActionBar({
    super.key,
    required this.onBackPressed,
    this.showCloseIcon = false,
  });

  final VoidCallback onBackPressed;
  final bool showCloseIcon;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      leftItem: BottomActionBarItem(
        child: HugeIcon(
          icon: showCloseIcon ? HugeIcons.solidSharpMultiplicationSign : HugeIcons.solidSharpArrowLeft02,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: onBackPressed,
      ),
    );
  }
}
