import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';

/// The single text input used across the app. One widget, one look: filled with
/// [cardColor], a 12px rounded 0.5px outline (primary when focused, error when
/// invalid), Google Sans text and themed hint/label/helper colours. Callers
/// vary only content and behaviour (hint, keyboard, validation, icons), never
/// the styling, so every field in the app reads as the same component.
///
/// When focused the input box grows a soft 4px translucent ring. It is drawn as
/// a [BoxShadow] (spread, no blur) around the box only, so it sits *outside* the
/// field without taking any layout space — nothing around the field moves when
/// it gains or loses focus. Helper/error text is laid out below the ringed box
/// so the ring hugs just the input, not the message.
class MeditoTextField extends StatefulWidget {
  const MeditoTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.helperMaxLines,
    this.errorText,
    this.counterText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLength,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  /// Applied to the inner [TextField] so `find.byKey` in widget tests keeps
  /// resolving to the field itself.
  final Key? fieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final int? helperMaxLines;
  final String? errorText;

  /// Pass `''` to suppress the character counter when [maxLength] is set.
  final String? counterText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLength;
  final int? maxLines;
  final TextAlign textAlign;

  /// Width of the focus ring drawn outside the field when focused.
  static const double _focusRingWidth = 4;

  @override
  State<MeditoTextField> createState() => _MeditoTextFieldState();
}

class _MeditoTextFieldState extends State<MeditoTextField> {
  FocusNode? _internalNode;
  late FocusNode _node;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? (_internalNode = FocusNode());
    _node.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MeditoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _node.removeListener(_handleFocusChange);
      if (widget.focusNode != null) {
        _internalNode?.dispose();
        _internalNode = null;
        _node = widget.focusNode!;
      } else {
        _node = _internalNode ??= FocusNode();
      }
      _node.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocusChange);
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withOpacityValue(0.6);
    final focused = _node.hasFocus;
    final hasError = widget.errorText != null;

    OutlineInputBorder borderWith(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    final normalBorder = borderWith(
      theme.colorScheme.outline.withOpacityValue(0.3),
      0.5,
    );
    final focusedBorder = borderWith(theme.colorScheme.primary, 1);
    final errorBorder = borderWith(theme.colorScheme.error, 1);
    final hintLabelStyle = TextStyle(fontFamily: googleSans, color: muted);

    // Helper / error live below the ringed box (see class doc), so keep them
    // out of the InputDecoration and drive the border colour ourselves.
    final field = TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLength: widget.maxLength,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      textAlign: widget.textAlign,
      cursorColor: onSurface,
      style: TextStyle(fontFamily: googleSans, color: onSurface),
      decoration: InputDecoration(
        // No floating label — the label is rendered statically above the box
        // (see below). Only the hint lives in the decoration.
        hintText: widget.hintText,
        counterText: widget.counterText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: theme.cardColor,
        hintStyle: hintLabelStyle,
        border: hasError ? errorBorder : normalBorder,
        enabledBorder: hasError ? errorBorder : normalBorder,
        focusedBorder: hasError ? errorBorder : focusedBorder,
        disabledBorder: normalBorder,
      ),
    );

    // The ring is a concentric rounded border sitting 4px outside the box: its
    // outer radius (12 + 4) matches the field's 12 so the corners curve
    // together smoothly. It's an overflowing [Positioned] in a non-clipping
    // [Stack], so it adds no layout size — siblings stay put whether or not the
    // field is focused.
    const ringWidth = MeditoTextField._focusRingWidth;
    final ringedBox = Stack(
      clipBehavior: Clip.none,
      children: [
        field,
        Positioned(
          left: -ringWidth,
          top: -ringWidth,
          right: -ringWidth,
          bottom: -ringWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              opacity: focused ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12 + ringWidth),
                  border: Border.all(
                    color: onSurface.withOpacityValue(0.18),
                    width: ringWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final label = widget.labelText;
    final subText = widget.errorText ?? widget.helperText;
    if (label == null && subText == null) return ringedBox;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: googleSans,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: onSurface.withOpacityValue(0.7),
              ),
            ),
          ),
        ringedBox,
        if (subText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              subText,
              maxLines: widget.helperMaxLines,
              overflow: widget.helperMaxLines != null
                  ? TextOverflow.ellipsis
                  : null,
              style: TextStyle(
                fontFamily: googleSans,
                fontSize: 12,
                color: hasError ? theme.colorScheme.error : muted,
              ),
            ),
          ),
      ],
    );
  }
}
