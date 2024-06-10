import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';

class RowItemWidget extends StatelessWidget {
  const RowItemWidget({
    super.key,
    required this.title,
    this.subTitle,
    required this.iconCodePoint,
    this.hasUnderline = true,
    this.onTap,
    this.isTrailingIcon = true,
    this.titleStyle,
    this.trailingIconSize = 24,
    this.leadingIconSize = 24,
    this.iconColor,
    this.enableInteractiveSelection = true,
  });

  final String title;
  final String? subTitle;
  final String iconCodePoint;
  final String? iconColor;
  final bool hasUnderline;
  final void Function()? onTap;
  final bool isTrailingIcon;
  final TextStyle? titleStyle;
  final double leadingIconSize;
  final double trailingIconSize;
  final bool enableInteractiveSelection;

  @override
  Widget build(BuildContext context) {
    var border = Border(
      bottom: hasUnderline
          ? BorderSide(
              width: 0.7,
              color: ColorConstants.ebony,
            )
          : BorderSide.none,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: border,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    IconData(
                      formatIcon(iconCodePoint),
                      fontFamily: 'MaterialIcons',
                    ),
                    color: iconColor != null
                        ? ColorConstants.getColorFromString(iconColor!)
                        : null,
                    size: leadingIconSize,
                  ),
                  width16,
                  SelectableText.rich(
                    enableInteractiveSelection: enableInteractiveSelection,
                    onTap: onTap,
                    scrollPhysics: NeverScrollableScrollPhysics(),
                    TextSpan(
                      style: TextStyle(fontSize: 18.0),
                      children: [
                        TextSpan(
                          text: title,
                          style: titleStyle ??
                              Theme.of(context).textTheme.labelMedium,
                        ),
                        if (subTitle != null) _subtitle(context),
                      ],
                    ),
                  ),
                ],
              ),
              Visibility(
                visible: isTrailingIcon,
                child: Icon(
                  Icons.chevron_right,
                  size: trailingIconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _subtitle(BuildContext context) {
    return TextSpan(
      text: '${subTitle != null ? '\n$subTitle' : ''}',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ColorConstants.graphite,
            letterSpacing: 0,
            height: 1.7,
          ),
    );
  }
}
