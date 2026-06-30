import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/medito_dialog.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';

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

  String _labelFor(int hours) {
    if (hours == 0) return 'Midnight (default)';
    return '$hours:00 AM';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final dirty = _selected != widget.currentHours;

    return MeditoDialog(
      title: 'When does your day start?',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick when a new day begins for your streak. Useful if you '
              'usually meditate late at night and want sessions after '
              'midnight to still count for the previous day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: dmSans,
                height: 1.5,
                color: onSurface.withOpacityValue(0.75),
              ),
            ),
            const SizedBox(height: 16),
            for (final hours in _options)
              _OffsetOptionTile(
                label: _labelFor(hours),
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
                      'Experimental. Changing this updates how every past '
                      'session is grouped into days, so your current and '
                      'longest streak may shift.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: dmSans,
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
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        MeditoDialogPrimaryButton(
          label: 'Save',
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
    final purple = context.brandPurple;

    return InkWell(
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
              color: selected ? purple : onSurface.withOpacityValue(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFamily: dmSans,
                  color: onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
