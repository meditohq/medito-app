import 'package:flutter/material.dart';
import 'bottom_action_bar.dart';

class SingleBackButtonActionBar extends StatelessWidget {
  const SingleBackButtonActionBar({
    super.key,
    required this.onBackPressed,
  });

  final void Function() onBackPressed;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      actions: [
        GestureDetector(
          onTap: onBackPressed,
          child: Icon(
            Icons.arrow_back,
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
