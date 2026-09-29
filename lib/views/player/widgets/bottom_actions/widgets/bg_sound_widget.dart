import 'dart:math' as math;

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/medito_icon.dart';

class BgSoundWidget extends ConsumerStatefulWidget {
  const BgSoundWidget({super.key, required this.isBackgroundSoundSelected});

  final bool isBackgroundSoundSelected;

  @override
  ConsumerState<BgSoundWidget> createState() => _BgSoundWidgetState();
}

class _BgSoundWidgetState extends ConsumerState<BgSoundWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      // 33⅓ rpm — one revolution every 1.8s, like a real turntable.
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    if (widget.isBackgroundSoundSelected) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BgSoundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBackgroundSoundSelected &&
        !oldWidget.isBackgroundSoundSelected) {
      _animationController.repeat();
    } else if (!widget.isBackgroundSoundSelected &&
        oldWidget.isBackgroundSoundSelected) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Display only: the action-bar slot owns the tap (opening the sheet) so the
  // whole button area responds, not just a nested inner button.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: widget.isBackgroundSoundSelected
          ? BoxDecoration(
              color: ColorConstants.graphite.withAlpha(200),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: widget.isBackgroundSoundSelected
          ? _spinningIcon()
          : MeditoIcon(
              assetName: MeditoIcons.musicNote,
              color: Colors.white,
              size: 23,
            ),
    );
  }

  Widget _spinningIcon() {
    return RotationTransition(
      turns: _animationController,
      child: const CustomPaint(
        size: Size.square(24),
        painter: _VinylPainter(color: ColorConstants.white),
      ),
    );
  }
}

/// A single-colour vinyl record in the style of the other action-bar icons:
/// a solid disc with short groove arcs, the label edge and the spindle hole
/// cut out. The arcs are off-centre, so the spin is visible.
class _VinylPainter extends CustomPainter {
  const _VinylPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;

    void groove(double radius, double startDeg, double sweepDeg) =>
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * radius),
          startDeg * math.pi / 180,
          sweepDeg * math.pi / 180,
          false,
          cut,
        );

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(center, r, Paint()..color = color);

    groove(0.74, 195, 60);
    groove(0.58, 205, 40);
    groove(0.74, 20, 45);

    canvas.drawCircle(center, r * 0.34, cut);
    canvas.drawCircle(
      center,
      r * 0.1,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) => oldDelegate.color != color;
}
