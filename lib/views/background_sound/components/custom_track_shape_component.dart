import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTrackShapeComponent extends RectangularSliderTrackShape {
  CustomTrackShapeComponent({required this.leadingTitle, required this.tralingText});
  final String tralingText;
  final String leadingTitle;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    var trackTop;
    trackTop = parentBox.size.height - trackHeight;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isDiscrete = false,
      bool isEnabled = false,
      double additionalActiveTrackHeight = 0}) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
    );
    final canvas = context.canvas;
    final textStyle = GoogleFonts.dmSans(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: ColorConstants.walterWhite,
    );
    TextPainter textPainter(span) => TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    var span = TextSpan(
      style: textStyle,
      text: leadingTitle,
    );
    var span1 = TextSpan(
      style: textStyle,
      text: tralingText,
    );
    var tp = textPainter(span);
    var tp1 = textPainter(span1);
    tp.layout();
    tp1.layout();
    final xCenter = tp.width - 50;
    final yCenter = tp.height + 2;
    final offset1 = Offset(xCenter, yCenter);
    final offset2 = Offset(parentBox.size.width * 0.85, yCenter);
    tp.paint(canvas, offset1);
    tp1.paint(canvas, offset2);
  }
}
