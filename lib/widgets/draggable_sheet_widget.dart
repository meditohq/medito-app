import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class DraggableSheetWidget extends StatelessWidget {
  const DraggableSheetWidget({
    super.key,
    required this.child,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.4,
    this.maxChildSize = 1,
  });
  final Widget Function(ScrollController scrollController) child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
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
