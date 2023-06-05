
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RowItemWidget extends StatelessWidget {
  const RowItemWidget({
    super.key,
    required this.title,
    required this.leadingIcon,
    this.isShowUnderline = true,
    this.onTap,
  });

  final String title;
  final String leadingIcon;
  final bool isShowUnderline;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    var border = Border(
      bottom: isShowUnderline
          ? BorderSide(
              width: 0.7,
              color: ColorConstants.darkMoon,
            )
          : BorderSide.none,
    );

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
                  SvgPicture.asset(
                    leadingIcon,
                    height: 14,
                  ),
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
