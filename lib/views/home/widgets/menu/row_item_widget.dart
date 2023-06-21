import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RowItemWidget extends StatelessWidget {
  const RowItemWidget({
    super.key,
    required this.title,
    required this.iconCodePoint,
    this.hasUnderline = true,
    this.onTap,
  });

  final String title;
  final String iconCodePoint;
  final bool hasUnderline;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    var border = Border(
      bottom: hasUnderline
          ? BorderSide(
              width: 0.7,
              color: ColorConstants.darkMoon,
            )
          : BorderSide.none,
    );
    var icon = int.parse('0x$iconCodePoint');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: border,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 15,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(IconData(icon, fontFamily: 'MaterialIcons')),
                  width16,
                  Text(title),
                ],
              ),
              SvgPicture.asset(
                AssetConstants.icForward,
                height: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
