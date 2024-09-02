import 'package:flutter/material.dart';

import 'bottom_action_bar.dart';

class SingleBackButtonActionBar extends StatelessWidget {
  const SingleBackButtonActionBar({
    super.key,
    required this.onBackPressed,
    this.showCloseIcon = false,
  });

  final void Function() onBackPressed;
  final bool showCloseIcon;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      actions: [
        GestureDetector(
          onTap: onBackPressed,
          child: Icon(
            showCloseIcon ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
      ],
    );
  }
}
