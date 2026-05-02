import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/widgets/onboarding/onboarding_option_button.dart';

/// A single question screen in the onboarding question flow.
///
/// Displays a question, optional subtext, and a list of tappable options.
/// Tapping an option waits [selectionDelay] then calls [onOptionSelected].
class OnboardingQuestionScreen extends StatefulWidget {
  const OnboardingQuestionScreen({
    super.key,
    required this.question,
    required this.subtext,
    required this.options,
    required this.stepLabel,
    required this.onOptionSelected,
    this.selectionDelay = const Duration(milliseconds: 200),
    this.pinnedTrailingCount = 0,
  });

  final String question;
  final String subtext;
  final List<String> options;

  /// E.g. "1 of 2"
  final String stepLabel;

  /// Called with the original (canonical) index of the selected option after
  /// [selectionDelay], regardless of the displayed (shuffled) position.
  final void Function(int index) onOptionSelected;
  final Duration selectionDelay;

  /// Number of trailing options to keep pinned at the end (excluded from the
  /// shuffle). Useful for items like "Other" that should always read last.
  final int pinnedTrailingCount;

  @override
  State<OnboardingQuestionScreen> createState() =>
      _OnboardingQuestionScreenState();
}

class _OnboardingQuestionScreenState extends State<OnboardingQuestionScreen> {
  int? _selectedIndex;
  late final List<int> _displayOrder;

  @override
  void initState() {
    super.initState();
    final total = widget.options.length;
    final pinned = widget.pinnedTrailingCount.clamp(0, total);
    final shuffleCount = total - pinned;
    final shuffled = List<int>.generate(shuffleCount, (i) => i);
    if (shuffleCount > 1) {
      shuffled.shuffle(Random());
    }
    final tail = List<int>.generate(pinned, (i) => shuffleCount + i);
    _displayOrder = [...shuffled, ...tail];
  }

  Future<void> _onTap(int index) async {
    if (_selectedIndex != null) return; // already selected
    setState(() => _selectedIndex = index);
    await Future<void>.delayed(widget.selectionDelay);
    widget.onOptionSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(padding24, padding16, padding24, padding24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stepLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: padding16),
          Text(
            widget.question,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtext,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(_displayOrder.length, (i) {
            final originalIndex = _displayOrder[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingOptionButton(
                label: widget.options[originalIndex],
                selected: _selectedIndex == originalIndex,
                onTap: () => _onTap(originalIndex),
              ),
            );
          }),
        ],
      ),
    );
  }
}
