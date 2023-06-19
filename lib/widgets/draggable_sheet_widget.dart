import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class DraggableSheetWidget extends StatelessWidget {
  const DraggableSheetWidget({super.key, required this.child});
  final Widget Function(ScrollController scrollController) child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 1,
      expand: false,
      builder: (
        BuildContext context,
        ScrollController scrollController,
      ) {
        return Container(
          decoration: BoxDecoration(
            color: ColorConstants.onyx,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: child(scrollController),
        );
      },
    );
  }
}
