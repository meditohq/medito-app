import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';

/// iOS has no API to pin a widget, so Settings' "Add Home Screen Widget" row
/// opens this sheet with the steps instead of Android's system pin dialog.
Future<void> showAddWidgetSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => const AddWidgetSheet(),
  );
}

class AddWidgetSheet extends StatelessWidget {
  const AddWidgetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final steps = [
      l10n.addWidgetStepHold,
      l10n.addWidgetStepEdit,
      l10n.addWidgetStepSearch,
      l10n.addWidgetStepAdd,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addWidgetSheetTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (final (i, step) in steps.indexed) ...[
              _Step(number: i + 1, text: step),
              const SizedBox(height: 12),
            ],
            Text(
              l10n.addWidgetFootnote,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onSurface.withValues(alpha: 0.1),
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
            ),
          ),
        ),
      ],
    );
  }
}
