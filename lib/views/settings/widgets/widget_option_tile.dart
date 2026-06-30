import 'package:flutter/material.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';

class WidgetOptionTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final VoidCallback onTap;
  final bool hasUnderline;

  const WidgetOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.hasUnderline = true,
  });

  @override
  Widget build(BuildContext context) {
    return RowItemWidget(
      icon: icon,
      title: title,
      hasUnderline: hasUnderline,
      onTap: onTap,
    );
  }
}
