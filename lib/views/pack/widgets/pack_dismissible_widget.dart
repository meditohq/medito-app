import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class PackDismissibleWidget extends StatelessWidget {
  const PackDismissibleWidget({
    super.key,
    required this.child,
    this.onUpdateCb,
  });

  final Widget child;
  final void Function()? onUpdateCb;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: _getDismissibleBackgroundWidget(),
      confirmDismiss: (direction) async {
        if (onUpdateCb != null) {
          onUpdateCb!();
        }

        return false; // Do not remove the item from the list
      },
      child: child,
    );
  }

  Widget _getDismissibleBackgroundWidget() => Container(
        color: ColorConstants.charcoal,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Icon(
                Icons.check,
                color: ColorConstants.walterWhite,
              ),
            ],
          ),
        ),
      );
}
