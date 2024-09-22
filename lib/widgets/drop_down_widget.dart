import 'package:medito/constants/constants.dart';
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
    this.disabledLabelText = '',
    required this.isLandscape,
  });

  final List<DropdownMenuItem<T>>? items;
  final void Function(T?)? onChanged;
  final T? value;
  final IconData? iconData;
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
  final String disabledLabelText;
  final bool isLandscape;

  bool get _isClickable => items != null && items!.length > 1;

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
      color: ColorConstants.white,
      fontWeight: FontWeight.w400,
      fontSize: 16,
    );

    return Container(
      height: isLandscape ? 56 : 48,  // Set height to 48 in portrait mode
      decoration: BoxDecoration(
        borderRadius: radius,
        color: ColorConstants.onyx,
      ),
      child: _buildContent(context, radius, textStyle),
    );
  }

  Widget _buildContent(BuildContext context, BorderRadius radius, TextStyle? textStyle) {
    return Material(
      color: ColorConstants.transparent,
      child: InkWell(
        onTap: _isClickable ? () => _showDropdown(context) : null,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (iconData != null)
                Icon(
                  iconData,
                  color: ColorConstants.white,
                ),
              if (iconData != null) SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getDisplayValue(),
                  style: textStyle,
                ),
              ),
              if (_isClickable)
                Icon(
                  Icons.keyboard_arrow_down,
                  color: ColorConstants.white,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayValue() {
    if (!_isClickable) {
      return disabledLabelText;
    }
    final selectedItem = items?.firstWhere((item) => item.value == value, orElse: () => items!.first);
    return (selectedItem?.child as Text).data ?? '';
  }

  void _showDropdown(BuildContext context) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Offset? offset = renderBox?.localToGlobal(Offset.zero);
    final Size size = renderBox?.size ?? Size.zero;

    if (offset != null && items != null) {
      showMenu<T>(
        context: context,
        position: RelativeRect.fromLTRB(
          offset.dx,
          offset.dy + size.height,
          offset.dx + size.width,
          offset.dy + size.height,
        ),
        items: items!.map((item) => PopupMenuItem<T>(
          value: item.value,
          child: Container(
            width: size.width - 24,  // Subtract horizontal padding
            height: isLandscape ? 56 : 48,
            alignment: AlignmentDirectional.centerStart,
            child: item.child,
          ),
        )).toList(),
        elevation: 8,
        color: ColorConstants.onyx,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ).then((T? newValue) {
        if (newValue != null && onChanged != null) {
          onChanged!(newValue);
        }
      });
    }
  }
}