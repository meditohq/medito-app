import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RowItemWidget extends StatelessWidget {
  const RowItemWidget({
    super.key,
    required this.title,
    this.subTitle,
    required this.iconCodePoint,
    this.isShowUnderline = true,
    this.onTap,
    this.isTrailingIcon = true,
    this.titleStyle,
    this.iconSize = 14,
  });

  final String title;
  final String? subTitle;
  final String iconCodePoint;
  final bool isShowUnderline;
  final void Function()? onTap;
  final bool isTrailingIcon;
  final TextStyle? titleStyle;
  final double iconSize;
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            Theme.of(context).textTheme.labelMedium,
                      ),
                      if (subTitle != null) _subtitle(context),
                    ],
                  ),
                ],
              ),
              Visibility(
                visible: isTrailingIcon,
                child: SvgPicture.asset(
                  AssetConstants.icForward,
                  height: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Text _subtitle(BuildContext context) {
    return Text(
      subTitle!,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(color: ColorConstants.graphite),
    );
  }
}
