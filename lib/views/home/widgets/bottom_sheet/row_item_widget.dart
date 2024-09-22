import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';

  class IconType {
    final IconData? iconData;
    final String? iconString;

    IconType.fromIconData(this.iconData) : iconString = null;

    IconType.fromString(this.iconString) : iconData = null;
  }

class RowItemWidget extends StatelessWidget {
  const RowItemWidget({
    super.key,
    required this.title,
    this.subTitle,
    required this.icon,
    this.hasUnderline = true,
    this.onTap,
    this.isTrailingIcon = true,
    this.isSwitch = false,
    this.switchValue,
    this.onSwitchChanged,
    this.titleStyle,
    this.trailingIconSize = 24,
    this.leadingIconSize = 24,
    this.iconColor,
    this.enableInteractiveSelection = true,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final String title;
  final String? subTitle;
  final IconType icon;
  final String? iconColor;
  final bool hasUnderline;
  final void Function()? onTap;
  final bool isTrailingIcon;
  final bool isSwitch;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final TextStyle? titleStyle;
  final double leadingIconSize;
  final double trailingIconSize;
  final bool enableInteractiveSelection;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    var border = Border(
      bottom: hasUnderline
          ? const BorderSide(
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
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildIcon(),
                  width16,
                  SelectableText.rich(
                    enableInteractiveSelection: enableInteractiveSelection,
                    onTap: onTap,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    TextSpan(
                      style: const TextStyle(fontSize: 18.0),
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
              if (isTrailingIcon && !isSwitch)
                Icon(
                  trailingIcon,
                  size: trailingIconSize,
                ),
              if (isSwitch)
                Switch(
                  value: switchValue ?? false,
                  onChanged: onSwitchChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    if (icon.iconData != null) {
      iconData = icon.iconData!;
    } else if (icon.iconString != null) {
      iconData = IconData(
        formatIcon(icon.iconString!),
        fontFamily: materialIcons,
      );
    } else {
      iconData = Icons.error;
    }

    return Icon(
      iconData,
      color: iconColor != null
          ? ColorConstants.getColorFromString(iconColor!)
          : null,
      size: leadingIconSize,
    );
  }

  TextSpan _subtitle(BuildContext context) {
    return TextSpan(
      text: subTitle != null ? '\n$subTitle' : '',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: ColorConstants.graphite,
        letterSpacing: 0,
        height: 1.7,
      ),
    );
  }
}
