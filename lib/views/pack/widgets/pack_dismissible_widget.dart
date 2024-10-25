import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

class PackDismissibleWidget extends StatelessWidget {
  const PackDismissibleWidget({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  final Widget child;
  final void Function() onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: _getDismissibleBackgroundWidget(),
      confirmDismiss: (direction) async {
        onDismissed();

        return false; // Do not remove the item from the list
      },
      child: child,
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
