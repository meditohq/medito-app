import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';

class ZenModeAnimation extends StatefulWidget {
  const ZenModeAnimation({super.key});

  @override
  State<ZenModeAnimation> createState() => _ZenModeAnimationState();
}

class _ZenModeAnimationState extends State<ZenModeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _blurAnimation;
  late String _selectedMessage;

  static const List<String> _messages = [
    "Well done for showing up.",
    "Thank you for practicing.",
    "Time well spent.",
    "A moment just for you.",
    "Grateful for this pause.",
    "Enjoy the rest of your day.",
    "Take this feeling with you.",
    "Carry this calm forward.",
    "Until next time.",
    "See you tomorrow.",
    "Session complete.",
    "Practice complete.",
    "Here and now.",
  ];

  @override
  void initState() {
    super.initState();
    final random = Random();
    _selectedMessage = _messages[random.nextInt(_messages.length)];

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _blurAnimation = Tween<double>(
      begin: 10.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Text(
                _selectedMessage,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: teachers,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
