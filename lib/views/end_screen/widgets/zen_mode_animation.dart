import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';

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
  bool _started = false;

  static List<String> _messages(AppLocalizations l10n) => [
    l10n.zenModeEndMessage1,
    l10n.zenModeEndMessage2,
    l10n.zenModeEndMessage3,
    l10n.zenModeEndMessage4,
    l10n.zenModeEndMessage5,
    l10n.zenModeEndMessage6,
    l10n.zenModeEndMessage7,
    l10n.zenModeEndMessage8,
    l10n.zenModeEndMessage9,
    l10n.zenModeEndMessage10,
    l10n.zenModeEndMessage11,
    l10n.zenModeEndMessage12,
    l10n.zenModeEndMessage13,
  ];

  // Picked once; the text is looked up per build so it follows the locale.
  int? _messageIndex;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce motion: show the message sharp and fully opaque straight away.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages(AppLocalizations.of(context)!);
    final message =
        messages[_messageIndex ??= Random().nextInt(messages.length)];
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
                message,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: googleSans,
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
