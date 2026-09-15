import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A thin stadium-shaped ring with a soft glow that travels around the
/// perimeter at constant speed, plus the reflections you would see on a
/// glossy rim: fainter glints at the light's mirror points that move against
/// it, and a faint sheen spilling onto the surface inside.
///
/// A plain [SweepGradient] rotated by angle looks uneven on a wide pill: the
/// highlight sprints along the flat edges and crawls around the rounded ends.
/// This painter samples the perimeter by arc length instead, so every light
/// moves at the same speed everywhere and the loop has no visible seam.
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

/// The travelling head plus its reflections. A glossy stadium reflects a
/// light at its mirror points: across the vertical axis, across the
/// horizontal axis, and through the centre. Those points run the other way
/// round the ring as the head advances, which is what sells them as
/// reflections rather than extra lights.
List<_Light> _lights(_RingGeometry g, double head, List<Offset> samples) {
  final p = g.positionAt(head);
  final c = g.center;
  final mirrors = <(Offset, double)>[
    (Offset(2 * c.dx - p.dx, p.dy), 0.5), // across the vertical axis
    (Offset(p.dx, 2 * c.dy - p.dy), 0.35), // across the horizontal axis
    (Offset(2 * c.dx - p.dx, 2 * c.dy - p.dy), 0.25), // opposite
  ];
  return [
    _Light(head, 1),
    for (final (point, strength) in mirrors)
      _Light(_nearestT(point, samples), strength),
  ];
}

/// Arc-length position of the perimeter sample closest to [point].
double _nearestT(Offset point, List<Offset> samples) {
  var best = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < samples.length; i++) {
    final d = (samples[i] - point).distanceSquared;
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best / samples.length;
}

/// Wrapped signed distance between two arc-length positions.
double _delta(double t, double from) {
  var d = t - from;
  if (d > 0.5) d -= 1;
  if (d < -0.5) d += 1;
  return d;
}

double _gauss(double d, double sigma) =>
    math.exp(-(d * d) / (2 * sigma * sigma));

class _StreakRingPainter extends CustomPainter {
  _StreakRingPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  /// Number of perimeter samples turned into gradient stops.
  static const _samples = 96;

  /// Opacity of the ring away from any light.
  static const _baseOpacity = 0.22;

  /// Head: a sharper leading edge and a longer trailing tail read as motion.
  static const _headSigma = 0.07;
  static const _tailSigma = 0.18;

  /// Reflections are tighter and symmetric.
  static const _glintSigma = 0.055;

  /// Soft halo that spills off the ring around each light. Sized in logical
  /// pixels rather than relative to the hairline ring so it reads as light
  /// cast onto the page around the pill, not as a thicker stroke.
  static const _bloomWidth = 14.0;
  static const _bloomBlur = 9.0;
  static const _bloomOpacity = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final g = _RingGeometry(size, strokeWidth);
    final head = animation.value;

    final positions = List.generate(
      _samples,
      (i) => g.positionAt(i / _samples),
    );
    final lights = _lights(g, head, positions);

    double intensity(double t) {
      var sum = 0.0;
      for (final light in lights) {
        final d = _delta(t, light.t);
        if (light.strength == 1) {
          // The head is a comet; everything else a plain glint.
          sum += _gauss(d, d > 0 ? _headSigma : _tailSigma);
        } else {
          sum += light.strength * _gauss(d, _glintSigma);
        }
      }
      return sum.clamp(0.0, 1.0);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true
      ..shader = _sweepShader(
        g,
        positions,
        (t) => _baseOpacity + (1 - _baseOpacity) * intensity(t),
      );

    final bloom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bloomWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _bloomBlur)
      ..shader = _sweepShader(
        g,
        positions,
        (t) => _bloomOpacity * intensity(t),
      );

    canvas.drawRRect(g.rrect, bloom);
    canvas.drawRRect(g.rrect, ring);
  }

  /// Turn per-sample alphas (indexed by arc length) into a seamless sweep
  /// gradient keyed by angle from the centre.
  ui.Shader _sweepShader(
    _RingGeometry g,
    List<Offset> positions,
    double Function(double t) alphaAt,
  ) {
    final points = <_Stop>[];
    for (var i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final angle = math.atan2(pos.dy - g.center.dy, pos.dx - g.center.dx);
      final u = ((angle / (2 * math.pi)) + 1) % 1;
      points.add(_Stop(u, alphaAt(i / positions.length)));
    }
    points.sort((a, b) => a.u.compareTo(b.u));

    // Close the loop so stop 0 and stop 1 share a colour.
    final first = points.first;
    final last = points.last;
    final span = (first.u + 1) - last.u;
    final seamLerp = span == 0 ? 0.0 : (1 - last.u) / span;
    final seam = ui.lerpDouble(last.a, first.a, seamLerp)!;

    return ui.Gradient.sweep(
      g.center,
      [_tint(seam), ...points.map((p) => _tint(p.a)), _tint(seam)],
      [0, ...points.map((p) => p.u), 1],
      TileMode.clamp,
      0,
      2 * math.pi,
    );
  }

  Color _tint(double alpha) => color.withValues(alpha: alpha.clamp(0, 1));

  @override
  bool shouldRepaint(_StreakRingPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.animation != animation;
}

/// Light spilling onto the pill's surface under the head and its reflections,
/// clipped to the inside of the ring. Painted over the child, so it is kept
/// faint enough to read as a sheen rather than a tint on the text.
class _StreakSheenPainter extends CustomPainter {
  _StreakSheenPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  static const _samples = 48;
  static const _peakOpacity = 0.10;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final g = _RingGeometry(size, strokeWidth);
    final positions = List.generate(
      _samples,
      (i) => g.positionAt(i / _samples),
    );
    final lights = _lights(g, animation.value, positions);
    final inner = g.rrect.deflate(strokeWidth / 2);
    final radius = size.height * 0.9;

    canvas.save();
    canvas.clipRRect(inner);
    for (final light in lights) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(g.positionAt(light.t), radius, [
          color.withValues(alpha: _peakOpacity * light.strength),
          color.withValues(alpha: 0),
        ]);
      canvas.drawRect(inner.outerRect, paint);
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
  const _Stop(this.u, this.a);
  final double u;
  final double a;
}
