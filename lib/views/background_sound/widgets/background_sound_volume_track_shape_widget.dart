import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BackgroundSoundVolumeTrackShapeWidget
    extends RectangularSliderTrackShape {
  BackgroundSoundVolumeTrackShapeWidget({
    required this.leadingTitle,
    required this.tralingText,
  });

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
    double trackTop;
    trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
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
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    Color foreground(Color? background) =>
        ThemeData.estimateBrightnessForColor(background ?? Colors.black) ==
            Brightness.light
        ? Colors.black
        : Colors.white;

    void paintLabels(Color color) {
      TextPainter label(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: color,
            fontFamily: googleSans,
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (rect.width / 2 - 32).clamp(0, double.infinity));
      final title = label(leadingTitle);
      final value = label(tralingText);
      final rtl = textDirection == TextDirection.rtl;
      title.paint(
        canvas,
        Offset(
          rtl ? rect.right - 16 - title.width : rect.left + 16,
          rect.center.dy - title.height / 2,
        ),
      );
      value.paint(
        canvas,
        Offset(
          rtl ? rect.left + 16 : rect.right - 16 - value.width,
          rect.center.dy - value.height / 2,
        ),
      );
    }

    paintLabels(foreground(sliderTheme.inactiveTrackColor));
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        textDirection == TextDirection.ltr ? rect.left : thumbCenter.dx,
        rect.top,
        textDirection == TextDirection.ltr ? thumbCenter.dx : rect.right,
        rect.bottom,
      ),
    );
    paintLabels(foreground(sliderTheme.activeTrackColor));
    canvas.restore();
  }
}
