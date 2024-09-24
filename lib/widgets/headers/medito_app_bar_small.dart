import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

class MeditoAppBarSmall extends StatelessWidget implements PreferredSizeWidget {
  const MeditoAppBarSmall({
    Key? key,
    this.title,
    this.titleWidget,
    this.isTransparent = false,
    this.hasBackButton = true,
    this.hasCloseButton = false,
    this.actions,
    this.closePressed,
  }) : super(key: key);

  final void Function()? closePressed;
  final Widget? titleWidget;
  final bool hasCloseButton;
  final bool isTransparent;
  final bool hasBackButton;
  final List<Widget>? actions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: null,
      automaticallyImplyLeading: false,
      centerTitle: true,
      actions: actions,
      elevation: 0,
      backgroundColor:
          isTransparent ? ColorConstants.transparent : ColorConstants.onyx,
      title: getTitleWidget(context),
    );
  }

  Widget getTitleWidget(BuildContext context) {
    return titleWidget == null
        ? Text(title ?? '', style: Theme.of(context).textTheme.displayLarge)
        : Row(children: [titleWidget!]);
  }

  @override
  Size get preferredSize => const Size.fromHeight(56.0);
}
