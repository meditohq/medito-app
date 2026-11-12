import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/theme/medito_text.dart';

/// One option in an [OptionPillGroup].
class PillOption {
  const PillOption({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
}

/// A small-caps section label over a wrapping row of pills, one selected:
/// the voice and length pickers on the Home hero sheet and Manage defaults.
class OptionPillGroup extends StatelessWidget {
  const OptionPillGroup({
    super.key,
    required this.label,
    required this.options,
  });

  final String label;
  final List<PillOption> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            label.toUpperCase(),
            style: context.text.label.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final option in options) _OptionPill(option)],
        ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill(this.option);

  final PillOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final selected = option.selected;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? context.brandAccent : theme.cardColor,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? context.brandAccent
                : onSurface.withValues(alpha: 0.10),
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: option.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              option.text,
              style: context.text.subtitle.copyWith(
                color: selected ? context.onBrandAccent : onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
