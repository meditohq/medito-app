import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';

class AnimatedFavouriteIcon extends StatefulWidget {
  const AnimatedFavouriteIcon({
    super.key,
    required this.isFavorite,
    required this.color,
    this.isPending = false,
  });

  final bool isFavorite;
  final Color color;

  /// While true, the icon spins. When the caller clears it, the spin
  /// decelerates with an overshoot back to upright.
  final bool isPending;

  @override
  State<AnimatedFavouriteIcon> createState() => AnimatedFavouriteIconState();
}

class AnimatedFavouriteIconState extends State<AnimatedFavouriteIcon>
    with TickerProviderStateMixin {
  // Entrance: fade in + scale-up + small initial rotation when the icon
  // first appears in the bar.
  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceRotationTurns;

  // While the favourite save is in flight, this controller drives a
  // tight 320ms-per-revolution spin via repeat().
  late final AnimationController _spinController;

  // When pending clears, this controller plays a one-shot deceleration
  // from the spin's current angle past upright (overshoot) and settling
  // back. Curve = easeOutBack for the snap-and-settle feel.
  late final AnimationController _releaseController;

  // The accumulated spin angle (in turns) at the moment pending cleared.
  // Held during the release animation so the curve carries from this
  // value to the next integer turn.
  double _releaseFromTurns = 0;
  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceScale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );
    _entranceRotationTurns = Tween<double>(
      begin: 0.12,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceController.forward();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _releaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    if (widget.isPending) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedFavouriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPending && !oldWidget.isPending) {
      _startSpin();
    } else if (!widget.isPending && oldWidget.isPending) {
      _startRelease();
    }
  }

  void _startSpin() {
    _isReleasing = false;
    _releaseController.reset();
    _spinController.repeat();
  }

  void _startRelease() {
    // Capture the current spin angle (a value in [0,1) representing turns
    // into the current revolution), stop the continuous spin, and run the
    // deceleration curve from there.
    _releaseFromTurns = _spinController.value;
    _spinController.stop();
    _spinController.value = 0;

    setState(() => _isReleasing = true);
    _releaseController.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _isReleasing = false);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _spinController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  /// Current rotation in turns (0..1+). Driven by whichever animation is
  /// active: the continuous spin while pending, the easeOutBack deceleration
  /// during release, or 0 at rest.
  double _currentTurns() {
    if (_isReleasing) {
      final t = Curves.easeOutBack.transform(_releaseController.value);
      // Carry from the captured spin angle to one full turn past it (which
      // is visually upright again for a rotationally-symmetric icon, but
      // the easeOutBack overshoot makes the settle visible regardless).
      return _releaseFromTurns + (1.0 - _releaseFromTurns) * t;
    }
    if (widget.isPending) {
      return _spinController.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final assetName =
        widget.isFavorite ? MeditoIcons.starSolid : MeditoIcons.star;

    final animatedIcon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scaleAnimation = Tween<double>(
          begin: 0.72,
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      child: MeditoIcon(
        key: ValueKey(assetName),
        assetName: assetName,
        color: widget.color,
      ),
    );

    return FadeTransition(
      opacity: _entranceOpacity,
      child: ScaleTransition(
        scale: _entranceScale,
        child: RotationTransition(
          turns: _entranceRotationTurns,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spinController, _releaseController]),
            builder: (context, child) {
              return Transform.rotate(
                angle: _currentTurns() * 2 * math.pi,
                child: child,
              );
            },
            child: animatedIcon,
          ),
        ),
      ),
    );
  }
}
