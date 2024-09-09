import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../constants/colors/color_constants.dart';

class StatsRow extends StatefulWidget {
  final VoidCallback leftButtonClicked;
  final VoidCallback rightButtonClicked;
  final String leftButtonText;
  final String rightButtonText;
  final IconData leftButtonIcon;
  final IconData rightButtonIcon;
  final Color leftButtonIconColor;
  final Color rightButtonIconColor;

  const StatsRow({
    Key? key,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.leftButtonClicked,
    required this.rightButtonClicked,
    required this.leftButtonIcon,
    required this.rightButtonIcon,
    required this.leftButtonIconColor,
    required this.rightButtonIconColor,
  }) : super(key: key);

  @override
  _StatsRowState createState() => _StatsRowState();
}

class _StatsRowState extends State<StatsRow> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 150),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOutExpo,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7.0),
    );

    var leftButtonStyle = TextButton.styleFrom(
      iconColor: widget.leftButtonIconColor,
      backgroundColor: ColorConstants.amsterdamSummer,
      shape: buttonShape,
    );

    var rightButtonStyle = TextButton.styleFrom(
      iconColor: widget.rightButtonIconColor,
      backgroundColor: ColorConstants.amsterdamSummer,
      shape: buttonShape,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: widget.leftButtonClicked,
              style: leftButtonStyle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.leftButtonIcon,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    widget.leftButtonText,
                    style: TextStyle(
                      color: ColorConstants.walterWhite,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: widget.rightButtonClicked,
              style: rightButtonStyle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge(
                      [_pulseAnimation, _rotationController, _fadeAnimation],
                    ),
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value * 0.1),
                            child: Icon(
                              widget.rightButtonIcon,
                              size: 20,
                              color: widget.rightButtonIconColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 4),
                  Text(
                    widget.rightButtonText,
                    style: TextStyle(
                      color: ColorConstants.walterWhite,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
