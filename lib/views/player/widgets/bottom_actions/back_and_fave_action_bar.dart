import 'package:Medito/views/player/widgets/bottom_actions/widgets/mark_favourite_widget.dart';
import 'package:flutter/material.dart';

import 'bottom_action_bar.dart';

class BackAndFaveActionBar extends StatelessWidget {
  const BackAndFaveActionBar({
    super.key,
    required this.onBackPressed,
    this.showCloseIcon = false,
    required this.trackId,
  });

  final void Function() onBackPressed;
  final bool showCloseIcon;
  final String trackId;

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
        MarkFavouriteWidget(trackId: trackId),
      ],
    );
  }
}
