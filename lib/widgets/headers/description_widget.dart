import 'package:flutter/material.dart';

import '../../constants/styles/widget_styles.dart';
import '../markdown_widget.dart';

class DescriptionWidget extends StatelessWidget {
  const DescriptionWidget({
    super.key,
    required this.description,
    this.endReserve = 0,
  });

  final String description;

  /// Width kept clear at the end of the last line, so something overlapping
  /// the bottom-right corner (the pack's play button) never covers text. A
  /// last line too long to share wraps its final word instead.
  final double endReserve;

  @override
  Widget build(BuildContext context) {
    if (description == '') {
      return Container();
    }
    final pStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontFamily: googleSans,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );

    return Container(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: MarkdownWidget(
          body: endReserve > 0
              ? '$description ${_spacer(context, pStyle)}'
              : description,
          selectable: true,
          textAlign: WrapAlignment.start,
          p: pStyle,
          a: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: googleSans,
            decoration: TextDecoration.underline,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  /// Non-breaking spaces glue into one unbreakable run, so it either fits at
  /// the end of the last line or moves to a line of its own.
  String _spacer(BuildContext context, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: '\u00A0', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width <= 0) return '';
    return '\u00A0' * (endReserve / width).ceil();
  }
}
