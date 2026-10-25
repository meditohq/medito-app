import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/medito_dialog.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';

/// "Midnight (default)" for 0, otherwise the hour in the locale's time format
/// (1:00 AM, 01:00, ...).
String dayBoundaryLabel(BuildContext context, int hours) {
  if (hours == 0) return AppLocalizations.of(context)!.dayStartsMidnightDefault;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: hours, minute: 0),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Dialog for picking when a new "day" begins for streak calculation.
///
/// Returns the chosen offset in whole hours on save, or `null` on cancel.
class DayBoundaryOffsetDialog extends StatefulWidget {
  final int currentHours;

  const DayBoundaryOffsetDialog({super.key, required this.currentHours});

  @override
  State<DayBoundaryOffsetDialog> createState() =>
      _DayBoundaryOffsetDialogState();
}

class _DayBoundaryOffsetDialogState extends State<DayBoundaryOffsetDialog> {
  static const _options = [0, 1, 2, 3, 4, 5, 6];

  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentHours.clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final dirty = _selected != widget.currentHours;
    final l10n = AppLocalizations.of(context)!;

    return MeditoDialog(
      title: l10n.dayStartsDialogTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.dayStartsDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: googleSans,
                height: 1.5,
                color: onSurface.withOpacityValue(0.75),
              ),
            ),
            const SizedBox(height: 16),
            for (final hours in _options)
              _OffsetOptionTile(
                label: dayBoundaryLabel(context, hours),
                selected: hours == _selected,
                onTap: () => setState(() => _selected = hours),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: onSurface.withOpacityValue(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: onSurface.withOpacityValue(0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: onSurface.withOpacityValue(0.75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.dayStartsExperimentalNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: googleSans,
                        height: 1.4,
                        color: onSurface.withOpacityValue(0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        MeditoDialogSecondaryButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        MeditoDialogPrimaryButton(
          label: l10n.save,
          onPressed: dirty ? () => Navigator.of(context).pop(_selected) : null,
        ),
      ],
    );
  }
}

class _OffsetOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OffsetOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = context.brandAccent;

    // The radio state was only an icon: announce it as a radio button.
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? accent : onSurface.withOpacityValue(0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: googleSans,
                    color: onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
