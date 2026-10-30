import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/utils/day_boundary.dart';

enum CalendarStampType { guided, timer, manual }

extension CalendarStampInk on CalendarStampType {
  Color ink(BuildContext context) {
    return switch (this) {
      CalendarStampType.guided ||
      CalendarStampType.timer => context.brandAccent,
      CalendarStampType.manual => Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.75),
    };
  }

  String get symbol => switch (this) {
    CalendarStampType.guided => AssetConstants.icLogo,
    CalendarStampType.timer => MeditoIcons.timerOutline,
    CalendarStampType.manual => MeditoIcons.pencil,
  };
}

/// A physical impression belongs to a calendar date, independent of build
/// order, timezone, selection, session count, and Dart's random/hash state.
@immutable
class CalendarStampImpression {
  CalendarStampImpression(DateTime date)
    : seed = date.year * 372 + date.month * 31 + date.day;

  final int seed;
  double _variation(int salt) => ((seed * salt + 17) % 101) / 100;
  Offset get offset =>
      Offset((_variation(37) - 0.5) * 5, (_variation(53) - 0.5) * 4);
  double get angle => (_variation(71) - 0.5) * 0.8;
}

/// Both calendars use the first real session on the user's logical day.
Map<DateTime, CalendarStampType> calendarStampsForSessions(
  Iterable<LocalAudioCompleted> sessions,
  Duration dayOffset,
) {
  final stamps = <DateTime, CalendarStampType>{};
  final ordered = sessions.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  for (final session in ordered) {
    if (session.id == TypeConstants.streakFreeze) continue;
    final date = dayOf(
      DateTime.fromMillisecondsSinceEpoch(session.timestamp),
      dayOffset,
    );
    stamps.putIfAbsent(date, () {
      if ([
        TypeConstants.manual1,
        TypeConstants.manual2,
        TypeConstants.manual3,
        TypeConstants.manual4,
      ].contains(session.id)) {
        return CalendarStampType.manual;
      }
      return timerSessionDuration(session.id) != null ||
              session.id == kLegacyTimerTrackId
          ? CalendarStampType.timer
          : CalendarStampType.guided;
    });
  }
  return stamps;
}

class CalendarStamp extends StatefulWidget {
  const CalendarStamp({
    super.key,
    required this.date,
    required this.type,
    this.animateIn = false,
    this.revealDelay = Duration.zero,
    this.onRevealComplete,
  });

  final DateTime date;
  final CalendarStampType type;
  final bool animateIn;
  final Duration revealDelay;
  final VoidCallback? onRevealComplete;

  @override
  State<CalendarStamp> createState() => _CalendarStampState();
}

class _CalendarStampState extends State<CalendarStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
        value: 1,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onRevealComplete?.call();
        }
      });
  Timer? _delay;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _reveal.value = 1;
      widget.onRevealComplete?.call();
    } else if (!_initialized && widget.animateIn) {
      _startReveal();
    }
    _initialized = true;
  }

  @override
  void didUpdateWidget(CalendarStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateIn &&
        !oldWidget.animateIn &&
        !MediaQuery.disableAnimationsOf(context)) {
      _startReveal();
    }
  }

  void _startReveal() {
    _delay?.cancel();
    _reveal.value = 0;
    if (widget.revealDelay == Duration.zero) {
      _reveal.forward();
    } else {
      _delay = Timer(widget.revealDelay, () => _reveal.forward());
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final impression = CalendarStampImpression(widget.date);
    final ink = widget.type.ink(context);
    final stamp = ExcludeSemantics(
      child: Transform.translate(
        offset: impression.offset,
        child: Transform.rotate(
          angle: impression.angle,
          child: SizedBox.square(
            dimension: 36,
            child: CustomPaint(
              painter: _StampRingPainter(ink, impression.seed),
              child: Center(
                child: MeditoIcon(
                  assetName: widget.type.symbol,
                  size: widget.type == CalendarStampType.guided ? 25 : 20,
                  color: ink.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _reveal,
      child: stamp,
      builder: (context, child) {
        final progress = Curves.easeOutBack.transform(_reveal.value);
        return Opacity(
          opacity: (_reveal.value * 5).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - progress)),
            child: Transform.scale(scale: 1.45 - 0.45 * progress, child: child),
          ),
        );
      },
    );
  }
}

class _StampRingPainter extends CustomPainter {
  const _StampRingPainter(this.ink, this.seed);
  final Color ink;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Short, uneven ink segments leave tiny dry patches in the double ring.
    for (var ring = 0; ring < 2; ring++) {
      final radius = size.shortestSide / 2 - 1.5 - ring * 3;
      for (var i = 0; i < 48; i++) {
        final wear = (seed + i * 17 + ring * 29) % 13;
        if (wear == 0) continue;
        final paint = Paint()
          ..color = ink.withValues(alpha: wear < 3 ? 0.45 : 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 0 ? 1.4 : 0.65;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * math.pi / 24,
          math.pi / 24 * 0.93,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StampRingPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.seed != seed;
}
