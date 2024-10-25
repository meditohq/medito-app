import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

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
  final Widget icon;
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
              color: ColorConstants.onyx,
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
                  icon,
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
