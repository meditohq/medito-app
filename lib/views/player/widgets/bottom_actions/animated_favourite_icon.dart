import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';

/// Direction of the in-flight favourite toggle. The icon animation differs
/// per direction so the user can read which way the toggle is going.
enum FavoriteToggleDirection { add, remove }

/// Owns the "is a favourite-toggle save in flight?" state for a single
/// [AnimatedFavouriteIcon]. Created in the parent widget's `initState` and
/// disposed in its `dispose`. Call [trigger] from the tap handler with the
/// actual save work; the controller handles the pending flag, the
/// minimum-visible-spin delay, and error swallowing so the parent doesn't
/// have to.
class FavoriteIconController extends ChangeNotifier {
  FavoriteIconController({
    this.minSpinDuration = const Duration(milliseconds: 200),
  });

  /// Minimum time the spin stays visible after a tap, even if the underlying
  /// save completes faster. Keeps the micro-interaction readable.
  final Duration minSpinDuration;

  bool _isPending = false;
  bool get isPending => _isPending;

  FavoriteToggleDirection _direction = FavoriteToggleDirection.add;
  FavoriteToggleDirection get direction => _direction;

  /// Runs [work] (the actual save) while the icon spins. The spin holds
  /// for at least [minSpinDuration] regardless of how fast [work] resolves.
  /// [direction] determines the visual flavour — clockwise + overshoot for
  /// `add`, counter-clockwise + clean ease-out for `remove`. Ignored if a
  /// previous trigger is still in flight.
  Future<void> trigger(
    Future<void> Function() work, {
    required FavoriteToggleDirection direction,
  }) async {
    if (_isPending) return;
    _isPending = true;
    _direction = direction;
    notifyListeners();

    final minSpin = Future<void>.delayed(minSpinDuration);
    try {
      await work();
    } catch (_) {
      // Swallow: the caller decides whether to surface errors; the icon
      // just shows the spin. Errors will already have been logged inside
      // the notifier.
    }
    await minSpin;

    _isPending = false;
    notifyListeners();
  }
}

class AnimatedFavouriteIcon extends StatefulWidget {
  const AnimatedFavouriteIcon({
    super.key,
    required this.isFavorite,
    required this.color,
    this.controller,
  });

  final bool isFavorite;
  final Color color;

  /// Optional. When provided, the icon spins while the controller reports
  /// pending and decelerates with an overshoot on release. When null, the
  /// icon is static (entrance + swap animations still play).
  final FavoriteIconController? controller;

  @override
  State<AnimatedFavouriteIcon> createState() => _AnimatedFavouriteIconState();
}

class _AnimatedFavouriteIconState extends State<AnimatedFavouriteIcon>
    with TickerProviderStateMixin {
  // Entrance: fade in + scale-up + small initial rotation when the icon
  // first appears in the bar.
  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceRotationTurns;

  // While the controller reports pending, this drives a tight
  // 320ms-per-revolution spin via repeat().
  late final AnimationController _spinController;

  // When the controller clears pending, this plays a one-shot deceleration
  // from the spin's current angle past upright (easeOutBack overshoot) and
  // settles. Both controllers feed the same Transform.rotate.
  late final AnimationController _releaseController;

  double _releaseFromTurns = 0;
  bool _isReleasing = false;
  bool _wasPending = false;
  // Captured at the moment pending became true so the in-flight direction
  // stays stable through both the spin and the release phases even if the
  // controller's direction changes mid-flight.
  FavoriteToggleDirection _activeDirection = FavoriteToggleDirection.add;

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
      duration: const Duration(milliseconds: 280),
    );
    _releaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    widget.controller?.addListener(_onPendingChanged);
    _wasPending = widget.controller?.isPending ?? false;
    if (_wasPending) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedFavouriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onPendingChanged);
      widget.controller?.addListener(_onPendingChanged);
      _wasPending = widget.controller?.isPending ?? false;
    }
  }

  void _onPendingChanged() {
    final controller = widget.controller;
    final pending = controller?.isPending ?? false;
    if (pending == _wasPending) return;
    _wasPending = pending;
    if (pending) {
      _activeDirection =
          controller?.direction ?? FavoriteToggleDirection.add;
      _startSpin();
    } else {
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
    widget.controller?.removeListener(_onPendingChanged);
    _entranceController.dispose();
    _spinController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  /// Current rotation in turns (always a positive magnitude — the direction
  /// sign is applied in [build]). Active source: the continuous spin while
  /// pending, the directional release curve during release, 0 at rest.
  ///
  /// Release curve:
  ///   add    -> easeOutBack: clockwise spin + small overshoot (celebratory)
  ///   remove -> easeOutCubic: counter-clockwise spin + clean settle (deflate)
  double _currentTurns() {
    if (_isReleasing) {
      final curve = _activeDirection == FavoriteToggleDirection.add
          ? Curves.easeOutBack
          : Curves.easeOutCubic;
      final t = curve.transform(_releaseController.value);
      return _releaseFromTurns + (1.0 - _releaseFromTurns) * t;
    }
    if (_wasPending) {
      return _spinController.value;
    }
    return 0;
  }

  /// Spin direction. +1 = clockwise (add), -1 = counter-clockwise (remove).
  double _directionSign() =>
      _activeDirection == FavoriteToggleDirection.add ? 1.0 : -1.0;

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
                angle: _directionSign() * _currentTurns() * 2 * math.pi,
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
