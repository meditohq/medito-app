import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

class PackDismissibleWidget extends StatefulWidget {
  const PackDismissibleWidget({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  final Widget child;
  final void Function() onDismissed;

  @override
  PackDismissibleWidgetState createState() => PackDismissibleWidgetState();
}

class PackDismissibleWidgetState extends State<PackDismissibleWidget> {
  double? _dragStartX;
  static const _leftEdgeThreshold = 20.0;

  void _handlePointerDown(PointerDownEvent event) {
    // Record the initial horizontal position using global coordinates
    _dragStartX = event.position.dx;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      // Removed onPointerUp to preserve _dragStartX until confirmDismiss
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.endToStart,
        background: _getDismissibleBackgroundWidget(),
        confirmDismiss: (direction) async {
          // Capture and clear the stored drag start position
          final startX = _dragStartX;
          _dragStartX = null;
          // If the gesture started near the left edge, cancel dismiss
          if (startX != null && startX < _leftEdgeThreshold) {
            return false;
          }
          widget.onDismissed();
          return false; // Do not remove the item from the list
        },
        child: widget.child,
      ),
    );
  }

  Widget _getDismissibleBackgroundWidget() => Container(
        color: ColorConstants.charcoal,
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Icon(
                Icons.check,
                color: ColorConstants.white,
              ),
            ],
          ),
        ),
      );
}
