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
    this.stepLabel,
    required this.onOptionSelected,
    this.selectionDelay = const Duration(milliseconds: 200),
    this.pinnedTrailingCount = 0,
    this.freeTextHint,
    this.freeTextLabel,
    this.onFreeTextSubmitted,
  });

  final String question;
  final String subtext;
  final List<String> options;

  /// E.g. "1 of 2". When null or empty, no step label is rendered — used for
  /// single-question flows where a step counter would read oddly.
  final String? stepLabel;

  /// Called with the original (canonical) index of the selected option after
  /// [selectionDelay], regardless of the displayed (shuffled) position.
  final void Function(int index) onOptionSelected;
  final Duration selectionDelay;

  /// Number of trailing options to keep pinned at the end (excluded from the
  /// shuffle). Useful for items like "Other" that should always read last.
  final int pinnedTrailingCount;

  /// Optional placeholder for a free-text input rendered below the chip
  /// options. When non-null together with [onFreeTextSubmitted], the input is
  /// shown as a final answer path — users either tap a chip or type their own
  /// response.
  final String? freeTextHint;

  /// Optional label rendered above the free-text input (e.g. "Something else?").
  final String? freeTextLabel;

  /// Called with the trimmed free-text value when the user submits the field.
  final void Function(String text)? onFreeTextSubmitted;

  @override
  State<OnboardingQuestionScreen> createState() =>
      _OnboardingQuestionScreenState();
}

class _OnboardingQuestionScreenState extends State<OnboardingQuestionScreen> {
  int? _selectedIndex;
  bool _submittedFreeText = false;
  late final List<int> _displayOrder;
  late final TextEditingController _freeTextController;
  late final FocusNode _freeTextFocusNode;

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
    _freeTextController = TextEditingController();
    _freeTextFocusNode = FocusNode();
    _freeTextController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freeTextController.dispose();
    _freeTextFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onTap(int index) async {
    if (_selectedIndex != null || _submittedFreeText) return;
    setState(() => _selectedIndex = index);
    await Future<void>.delayed(widget.selectionDelay);
    widget.onOptionSelected(index);
  }

  void _onFreeTextSubmit() {
    if (_selectedIndex != null || _submittedFreeText) return;
    final text = _freeTextController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittedFreeText = true);
    _freeTextFocusNode.unfocus();
    widget.onFreeTextSubmitted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        padding24,
        padding16,
        padding24,
        padding24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.stepLabel != null && widget.stepLabel!.isNotEmpty) ...[
            Text(
              widget.stepLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: padding16),
          ],
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
          if (widget.freeTextHint != null && widget.onFreeTextSubmitted != null)
            _buildFreeTextField(theme),
        ],
      ),
    );
  }

  Widget _buildFreeTextField(ThemeData theme) {
    final disabled = _selectedIndex != null || _submittedFreeText;
    final hasText = _freeTextController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.freeTextLabel != null) ...[
            Text(
              widget.freeTextLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _freeTextController,
            focusNode: _freeTextFocusNode,
            enabled: !disabled,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onFreeTextSubmit(),
            maxLength: 80,
            decoration: InputDecoration(
              hintText: widget.freeTextHint,
              counterText: '',
              suffixIcon: hasText && !disabled
                  ? IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _onFreeTextSubmit,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
