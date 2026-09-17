import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:medito/views/bottom_navigation/widgets/floating_nav_bar.dart';
import 'package:medito/views/bottom_navigation/widgets/floating_search_field.dart';

/// Floating rounded search field with a Cancel button beside it, meant to sit
/// just above the keyboard while search is open. A frosted glass pill (blur,
/// hairline, soft shadow) holds the field; Cancel closes search.
class FloatingSearchBar extends StatelessWidget {
  const FloatingSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onCancel,
    required this.cancelLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final String cancelLabel;

  static const _radius = 100.0;
  static const _blurSigma = 24.0;
  static const _height = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = FloatingNavBar.colorsOf(context);
    final radius = BorderRadius.circular(_radius);

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: radius,
              border: Border.all(color: colors.rim, width: 0.5),
            ),
            child: SizedBox(
              height: _height,
              child: FloatingSearchField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onClear: onClear,
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(child: pill),
        TextButton(
          onPressed: onCancel,
          child: Text(
            cancelLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.2,
              color: colors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
