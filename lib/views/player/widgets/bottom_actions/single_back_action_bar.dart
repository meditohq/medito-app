import 'package:flutter/material.dart';

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
        child: Icon(
          showCloseIcon ? Icons.close : Icons.arrow_back,
          color: Colors.white,
        ),
        onTap: onBackPressed,
      ),
    );
  }
}
