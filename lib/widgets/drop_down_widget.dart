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
  });
  final List<DropdownMenuItem<T>>? items;
  final void Function(T?)? onChanged;
  final T? value;
  final IconData? iconData;
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
  @override
  Widget build(BuildContext context) {
    var radius = BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: Radius.circular(bottomRight),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: ColorConstants.onyx,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (iconData != null)
            Icon(
              iconData,
              color: ColorConstants.walterWhite,
            ),
          if (iconData != null) width12,
          Expanded(
            child: DropdownButton<T>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down),
              isExpanded: true,
              style: Theme.of(context).primaryTextTheme.bodyMedium?.copyWith(
                    fontFamily: DmMono,
                    color: ColorConstants.walterWhite,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
              onChanged: onChanged,
              dropdownColor: ColorConstants.onyx,
              focusColor: ColorConstants.onyx,
              borderRadius: radius,
              underline: SizedBox(),
              items: items,
            ),
          ),
        ],
      ),
    );
  }
}
