// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';

const _kStage2AutoDismissMs = 2000;

/// A one-time explainer strip that attaches flush below the Your Path card.
/// The card's bottom corners must be square when this strip is visible so they
/// form a single connected unit.
class YourPathExplainerStrip extends ConsumerStatefulWidget {
  const YourPathExplainerStrip({super.key});

  @override
  ConsumerState<YourPathExplainerStrip> createState() =>
      _YourPathExplainerStripState();
}

class _YourPathExplainerStripState extends ConsumerState<YourPathExplainerStrip>
    with TickerProviderStateMixin {
  _StripStage _stage = _StripStage.stage1;
  bool _collapsed = false;

  late final AnimationController _collapseController;
  late final Animation<double> _heightFactor;

  // Cross-fade controllers
  late final AnimationController _fadeController;
  late final Animation<double> _fadeStage1;
  late final Animation<double> _fadeStage2;

  @override
  void initState() {
    super.initState();

    final prefs = ref.read(sharedPreferencesProvider);
    final alreadySeen =
        prefs.getBool(SharedPreferenceConstants.hasSeenYourPathExplainer) ??
        false;
    _collapsed = alreadySeen;

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: alreadySeen ? 0.0 : 1.0,
    );
    _heightFactor = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fadeStage1 = _fadeController;
    _fadeStage2 = ReverseAnimation(_fadeController);

    if (!alreadySeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logStripShown();
      });
    }
  }

  void _logStripShown() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: AnalyticsEventConstants.yourPathExplainerShown),
    );
  }

  Future<void> _onGotItTapped() async {
    // Fade out stage 1, fade in stage 2
    setState(() => _stage = _StripStage.stage2);
    await _fadeController.reverse();

    // Wait for stage 2 display duration then collapse
    await Future.delayed(const Duration(milliseconds: _kStage2AutoDismissMs));

    if (!mounted) return;
    await _collapse(dismissMethod: 'auto');
  }

  Future<void> _collapse({required String dismissMethod}) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.yourPathExplainerDismissed,
            parameters: {
              AnalyticsEventConstants.paramDismissMethod: dismissMethod,
            },
          ),
    );

    await _collapseController.reverse();

    if (!mounted) return;
    setState(() => _collapsed = true);

    // Persist the dismissal
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
      SharedPreferenceConstants.hasSeenYourPathExplainer,
      true,
    );
  }

  @override
  void dispose() {
    _collapseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Subtle separator tint — just slightly darker than the card in both modes.
    final isDark = theme.brightness == Brightness.dark;
    final stripBackground =
        Color.lerp(theme.cardColor, Colors.black, isDark ? 0.15 : 0.05) ??
        theme.cardColor;

    final l10n = AppLocalizations.of(context)!;

    return SizeTransition(
      sizeFactor: _heightFactor,
      alignment: AlignmentDirectional.topStart,
      child: Container(
        color: stripBackground,
        padding: const EdgeInsets.fromLTRB(
          padding16,
          padding12,
          padding16,
          padding16,
        ),
        child: _stage == _StripStage.stage1
            ? _Stage1Content(
                fadeAnimation: _fadeStage1,
                text: l10n.yourPathExplainerText,
                buttonLabel: l10n.gotIt,
                onGotIt: _onGotItTapped,
              )
            : _Stage2Content(
                fadeAnimation: _fadeStage2,
                text: l10n.yourPathExplainerSwipeHint,
              ),
      ),
    );
  }
}

enum _StripStage { stage1, stage2 }

class _Stage1Content extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final String text;
  final String buttonLabel;
  final VoidCallback onGotIt;

  const _Stage1Content({
    required this.fadeAnimation,
    required this.text,
    required this.buttonLabel,
    required this.onGotIt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: teachers,
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onGotIt,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(44, 44),
              foregroundColor: ColorConstants.lightBlue,
            ),
            child: Text(
              buttonLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: teachers,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorConstants.lightBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stage2Content extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final String text;

  const _Stage2Content({required this.fadeAnimation, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: Row(
        children: [
          const Icon(
            Icons.swipe_left_rounded,
            size: 18,
            color: ColorConstants.lightBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: teachers,
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
