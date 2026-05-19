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

  /// When true, the icon continuously rotates. Used to show that a save is
  /// in flight after the user taps. The caller is responsible for clearing
  /// this once the save (and any minimum-spin-time pad) has completed.
  final bool isPending;

  @override
  State<AnimatedFavouriteIcon> createState() => AnimatedFavouriteIconState();
}

class AnimatedFavouriteIconState extends State<AnimatedFavouriteIcon>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceRotationTurns;

  late final AnimationController _spinController;

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
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPending) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedFavouriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPending && !oldWidget.isPending) {
      _spinController.repeat();
    } else if (!widget.isPending && oldWidget.isPending) {
      // Let the in-flight rotation finish to the next full turn so the icon
      // doesn't jolt to a stop mid-spin.
      _spinController.animateTo(1.0).whenComplete(() {
        if (mounted) _spinController.reset();
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetName =
        widget.isFavorite ? MeditoIcons.starSolid : MeditoIcons.star;

    return FadeTransition(
      opacity: _entranceOpacity,
      child: ScaleTransition(
        scale: _entranceScale,
        child: RotationTransition(
          turns: _entranceRotationTurns,
          child: RotationTransition(
            turns: _spinController,
            child: AnimatedSwitcher(
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
            ),
          ),
        ),
      ),
    );
  }
}
