import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A thin stadium-shaped ring with a bright glint that travels around the
/// perimeter at constant speed, the way a light catches a polished rim: a
/// small hot specular point, a tight halo around it, a long tail fading out
/// behind, a fainter echo of it on the opposite side of the rim, and a soft
/// sheen on the surface inside.
///
/// A plain [SweepGradient] rotated by angle looks uneven on a wide pill: the
/// highlight sprints along the flat edges and crawls around the rounded ends.
/// This painter samples the perimeter by arc length instead, so every light
/// moves at the same speed everywhere and the loop has no visible seam.
///
/// With a light [color] the pill is taken to be dark and the light glows on
/// it. With a dark [color] the pill is light, where a white highlight has
/// nothing to show against, so it is first given a polished-silver finish
/// (grey shading, soft drop shadow, grey rim) for the same white light to
/// catch.
class StreakRing extends StatelessWidget {
  const StreakRing({
    super.key,
    required this.animation,
    required this.color,
    required this.strokeWidth,
    required this.child,
  });

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StreakRingPainter(
          animation: animation,
          color: color,
          strokeWidth: strokeWidth,
        ),
        foregroundPainter: _StreakSheenPainter(
          animation: animation,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Padding(padding: EdgeInsets.all(strokeWidth), child: child),
      ),
    );
  }
}

/// The ring's outline path and the measurements both painters need.
class _RingGeometry {
  _RingGeometry(Size size, double strokeWidth) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final radius = math.min(rect.width, rect.height) / 2;
    rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    center = rect.center;
    metric = (Path()..addRRect(rrect)).computeMetrics().first;
    perimeter = metric.length;
  }

  late final RRect rrect;
  late final Offset center;
  late final ui.PathMetric metric;
  late final double perimeter;

  Offset positionAt(double t) =>
      metric.getTangentForOffset((t % 1) * perimeter)!.position;
}

/// A light source on the perimeter: where it is (0..1 by arc length) and how
/// bright, relative to the head.
class _Light {
  const _Light(this.t, this.strength);
  final double t;
  final double strength;
}

/// The travelling head plus its echo: a fainter copy exactly half the
/// perimeter away, so the two always sit opposite each other and circle at
/// the same speed in the same direction, like one light and its reflection
/// on the far side of the rim.
List<_Light> _lights(double head) => [
  _Light(head, 1),
  _Light((head + 0.5) % 1, _echoStrength),
];

const _echoStrength = 0.45;

/// Wrapped signed distance between two arc-length positions.
double _delta(double t, double from) {
  var d = t - from;
  if (d > 0.5) d -= 1;
  if (d < -0.5) d += 1;
  return d;
}

double _gauss(double d, double sigma) =>
    math.exp(-(d * d) / (2 * sigma * sigma));

/// Whether [color] is a light accent, i.e. the pill it rings is dark.
bool _onDark(Color color) => color.computeLuminance() > 0.5;

class _StreakRingPainter extends CustomPainter {
  _StreakRingPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  /// Number of perimeter samples turned into gradient stops. Dense enough
  /// (~1pt apart) that the narrow hot core stays smooth as it moves.
  static const _samples = 200;

  /// Opacity of the ring away from any light.
  static const _baseOpacity = 0.2;

  /// Head glow: a sharp leading edge and a long trailing tail read as motion.
  static const _headSigma = 0.022;
  static const _tailSigma = 0.14;

  /// Hot core riding at the very front of the head.
  static const _coreLeadSigma = 0.008;
  static const _coreTailSigma = 0.035;

  /// Halo hugging the ring around each light. Kept tight: a wide blur reads
  /// as smoke around the pill, a narrow one as shine on its edge.
  static const _bloomWidth = 3.0;
  static const _bloomBlur = 2.5;
  static const _bloomOpacity = 0.55;

  /// Light surface only: rim opacity away from the light, and the soft drop
  /// shadow that lifts the pill off the page so its bright edge reads.
  static const _lightBaseOpacity = 0.3;
  static const _shadowOpacity = 0.2;
  static const _shadowBlur = 5.0;
  static const _shadowOffset = Offset(0, 2);

  /// Specular point at the head: a small soft flare with a crisp centre.
  static const _flareRadius = 3.2;
  static const _flareBlur = 2.6;
  static const _sparkRadius = 1.1;
  static const _sparkBlur = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final g = _RingGeometry(size, strokeWidth);
    final head = animation.value;

    final positions = List.generate(
      _samples,
      (i) => g.positionAt(i / _samples),
    );
    final lights = _lights(head);

    // Both lights are the same comet (sharp front, trailing tail); the echo
    // is just dimmer.
    double glow(double t) {
      var sum = 0.0;
      for (final light in lights) {
        final d = _delta(t, light.t);
        sum += light.strength * _gauss(d, d > 0 ? _headSigma : _tailSigma);
      }
      return sum.clamp(0.0, 1.0);
    }

    double core(double t) {
      final d = _delta(t, head);
      return _gauss(d, d > 0 ? _coreLeadSigma : _coreTailSigma);
    }

    final onDark = _onDark(color);
    // On a dark pill the light is the accent burning out to white; on a light
    // one it is white throughout, over a grey rim.
    final light = onDark ? color : Colors.white;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true
      ..shader = _sweepShader(g, positions, (t) {
        final c = core(t);
        final lit = math.max(glow(t), c);
        if (!onDark) {
          return Color.lerp(
            color.withValues(alpha: _lightBaseOpacity),
            Colors.white,
            lit,
          )!;
        }
        final alpha = _baseOpacity + (1 - _baseOpacity) * lit;
        return Color.lerp(color, Colors.white, c)!.withValues(alpha: alpha);
      });

    final bloom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bloomWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _bloomBlur)
      ..shader = _sweepShader(
        g,
        positions,
        (t) =>
            light.withValues(alpha: (onDark ? _bloomOpacity : 0.9) * glow(t)),
      );

    if (!onDark) {
      canvas.drawRRect(
        g.rrect.shift(_shadowOffset),
        Paint()
          ..color = Colors.black.withValues(alpha: _shadowOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowBlur),
      );
    }
    canvas.drawRRect(g.rrect, bloom);
    canvas.drawRRect(g.rrect, ring);

    // The specular point itself, sitting just behind the leading edge.
    final point = g.positionAt(head - _coreLeadSigma);
    canvas.drawCircle(
      point,
      _flareRadius,
      Paint()
        ..color = light.withValues(alpha: onDark ? 0.7 : 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _flareBlur),
    );
    canvas.drawCircle(
      point,
      _sparkRadius,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _sparkBlur),
    );
  }

  /// Turn per-sample colours (indexed by arc length) into a seamless sweep
  /// gradient keyed by angle from the centre.
  ui.Shader _sweepShader(
    _RingGeometry g,
    List<Offset> positions,
    Color Function(double t) colorAt,
  ) {
    final points = <_Stop>[];
    for (var i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final angle = math.atan2(pos.dy - g.center.dy, pos.dx - g.center.dx);
      final u = ((angle / (2 * math.pi)) + 1) % 1;
      points.add(_Stop(u, colorAt(i / positions.length)));
    }
    points.sort((a, b) => a.u.compareTo(b.u));

    // Close the loop so stop 0 and stop 1 share a colour.
    final first = points.first;
    final last = points.last;
    final span = (first.u + 1) - last.u;
    final seamLerp = span == 0 ? 0.0 : (1 - last.u) / span;
    final seam = Color.lerp(last.color, first.color, seamLerp)!;

    return ui.Gradient.sweep(
      g.center,
      [seam, ...points.map((p) => p.color), seam],
      [0, ...points.map((p) => p.u), 1],
      TileMode.clamp,
      0,
      2 * math.pi,
    );
  }

  @override
  bool shouldRepaint(_StreakRingPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.animation != animation;
}

/// The pill's surface finish, clipped to the inside of the ring: a fixed
/// glassy highlight along the top edge, plus light pooling under the head and
/// its echo as they pass. Painted over the child, so it is kept faint
/// enough to read as a sheen rather than a tint on the text.
class _StreakSheenPainter extends CustomPainter {
  _StreakSheenPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  static const _peakOpacity = 0.16;
  static const _glassOpacity = 0.07;

  /// Light surface: grey shading, and stronger whites to show against it.
  static const _shadeTop = 0.04;
  static const _shadeBottom = 0.14;
  static const _lightGlassOpacity = 0.5;
  static const _lightPeakOpacity = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final g = _RingGeometry(size, strokeWidth);
    final lights = _lights(animation.value);
    final inner = g.rrect.deflate(strokeWidth / 2);
    final bounds = inner.outerRect;
    final radius = size.height * 0.6;

    final onDark = _onDark(color);
    final light = onDark ? color : Colors.white;

    canvas.save();
    canvas.clipRRect(inner);
    if (!onDark) {
      // Silver body: shade the white pill grey, darker towards the bottom, so
      // the highlights below have something to stand out from.
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [
            Colors.black.withValues(alpha: _shadeTop),
            Colors.black.withValues(alpha: _shadeBottom),
          ]),
      );
    }
    // Glass: brightest right under the top rim, gone by mid-height.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(bounds.topCenter, bounds.center, [
          Colors.white.withValues(
            alpha: onDark ? _glassOpacity : _lightGlassOpacity,
          ),
          Colors.white.withValues(alpha: 0),
        ]),
    );
    for (final l in lights) {
      final peak = (onDark ? _peakOpacity : _lightPeakOpacity) * l.strength;
      // Falls off fast near the rim, then trails away: a pool of light, not
      // an even fog.
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          g.positionAt(l.t),
          radius,
          [
            light.withValues(alpha: peak),
            light.withValues(alpha: peak * 0.3),
            light.withValues(alpha: 0),
          ],
          [0, 0.4, 1],
        );
      canvas.drawRect(bounds, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StreakSheenPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.animation != animation;
}

class _Stop {
  const _Stop(this.u, this.color);
  final double u;
  final Color color;
}
