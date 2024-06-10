import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class DropdownWidget<T> extends StatelessWidget {
  const DropdownWidget({
    super.key,
    required this.items,
    this.onChanged,
    this.value,
    this.iconData,
    this.topLeft = 14,
    this.topRight = 14,
    this.bottomLeft = 14,
    this.bottomRight = 14,
    this.isDisabled = true,
    this.disabledLabelText = '',
  });

  final List<DropdownMenuItem<T>>? items;
  final void Function(T?)? onChanged;
  final T? value;
  final IconData? iconData;
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
  final bool isDisabled;
  final String disabledLabelText;

  @override
  Widget build(BuildContext context) {
    var radius = BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );
    var textStyle = Theme.of(context).primaryTextTheme.bodyMedium?.copyWith(
          fontFamily: DmMono,
          color: ColorConstants.walterWhite,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: ColorConstants.onyx,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: _buildRow(radius, textStyle),
    );
  }

  Row _buildRow(
    BorderRadius radius,
    TextStyle? textStyle,
  ) {
    return Row(
      children: [
        if (iconData != null)
          Icon(
            iconData,
            color: ColorConstants.walterWhite,
          ),
        if (iconData != null) width12,
        isDisabled
            ? _dropdown(textStyle, radius)
            : SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    disabledLabelText,
                    style: textStyle,
                  ),
                ),
              ),
      ],
    );
  }

  Expanded _dropdown(TextStyle? textStyle, BorderRadius radius) {
    return Expanded(
      child: DropdownButton<T>(
        value: value,
        icon: isDisabled ? const Icon(Icons.keyboard_arrow_down) : SizedBox(),
        isExpanded: true,
        style: textStyle,
        onChanged: onChanged,
        dropdownColor: ColorConstants.onyx,
        focusColor: ColorConstants.onyx,
        borderRadius: radius,
        underline: SizedBox(),
        items: items,
      ),
    );
  }
}
