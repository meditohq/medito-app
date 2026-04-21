import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';

/// Text field used inside Medito dialogs.
///
/// Matches the explore-screen [SearchBox] visually: filled with [cardColor],
/// 0.5px outline at 30% onSurface, 12px rounded corners, and a consistent
/// hint/text color derived from the theme.
class MeditoDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  const MeditoDialogTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineSide = BorderSide(
      color: theme.colorScheme.outline.withOpacityValue(0.3),
      width: 0.5,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: outlineSide,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: dmSans,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.cardColor,
        labelStyle: TextStyle(
          fontFamily: dmSans,
          color: theme.colorScheme.onSurface.withOpacityValue(0.69),
        ),
        hintStyle: TextStyle(
          fontFamily: dmSans,
          color: theme.colorScheme.onSurface.withOpacityValue(0.69),
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: border,
        focusedErrorBorder: border,
        disabledBorder: border,
      ),
    );
  }
}
