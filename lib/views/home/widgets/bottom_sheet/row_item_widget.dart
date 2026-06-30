import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/utils/utils.dart';

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
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final String title;
  final String? subTitle;
  final Widget icon;
  final Color? iconColor;
  final bool hasUnderline;
  final void Function()? onTap;
  final bool isTrailingIcon;
  final bool isSwitch;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final TextStyle? titleStyle;
  final double leadingIconSize;
  final double trailingIconSize;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    var border = Border(
      bottom: hasUnderline
          ? BorderSide(
              width: 0.7,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacityValue(0.2),
            )
          : BorderSide.none,
    );

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(border: border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildIconWithColor(),
                      width16,
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(fontSize: 18.0),
                            children: [
                              TextSpan(
                                text: title,
                                style:
                                    titleStyle ??
                                    Theme.of(
                                      context,
                                    ).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              if (subTitle != null) _subtitle(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTrailingIcon && !isSwitch)
                  Icon(
                    trailingIcon,
                    size: trailingIconSize,
                    color: Theme.of(context).colorScheme.onSurface,
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
      ),
    );
  }

  Widget _buildIconWithColor() {
    if (iconColor != null && icon is MeditoRemoteIcon) {
      final meditoIcon = icon as MeditoRemoteIcon;
      return MeditoRemoteIcon(
        icon: meditoIcon.icon,
        color: iconColor,
        size: meditoIcon.size,
      );
    }
    return icon;
  }

  TextSpan _subtitle(BuildContext context) {
    return TextSpan(
      text: subTitle != null ? '\n$subTitle' : '',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0,
        height: 1.7,
      ),
    );
  }
}
