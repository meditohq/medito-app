import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

class ManualSessionDialog extends StatefulWidget {
  final DateTime selectedDate;

  const ManualSessionDialog({
    super.key,
    required this.selectedDate,
  });

  @override
  State<ManualSessionDialog> createState() => _ManualSessionDialogState();
}

class _ManualSessionDialogState extends State<ManualSessionDialog> {
  TimeOfDay? _selectedTime;
  final TextEditingController _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  bool _isFutureSession() {
    if (_selectedTime == null) return false;

    final selectedDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    return selectedDateTime.isAfter(DateTime.now());
  }

  Future<void> _selectTime(BuildContext context) async {
    // No Theme override here — showTimePicker inherits the app theme, which
    // already routes a WCAG-AA primary through ColorScheme in both modes.
    // The previous override hardcoded ColorScheme.light(...) which produced
    // white-on-white text inside the picker when the app was in dark mode,
    // and a sub-AA lightPurple primary in light mode.
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return MeditoDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeditoDialogTitle(l10n.addSession),
          const SizedBox(height: 12),
          MeditoDialogBody(l10n.addSessionExplanation),
          const SizedBox(height: 20),
          _buildTimePickerTile(context, l10n),
          const SizedBox(height: 12),
          MeditoDialogTextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            labelText:
                '${l10n.duration} (in ${l10n.minutes.toLowerCase()}, ${l10n.optional.toLowerCase()})',
            hintText: l10n.minutes,
            prefixIcon: Icon(
              Icons.timer,
              color: theme.colorScheme.onSurface,
            ),
            suffixIcon: _durationController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color:
                          theme.colorScheme.onSurface.withOpacityValue(0.6),
                    ),
                    onPressed: () {
                      _durationController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          if (_isFutureSession()) ...[
            const SizedBox(height: 12),
            Text(
              l10n.cannotAddFutureSession,
              style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: dmSans,
                    color: theme.colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MeditoDialogSecondaryButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MeditoDialogPrimaryButton(
                  label: l10n.add,
                  onPressed: _isFutureSession()
                      ? null
                      : () {
                          final selectedDateTime = DateTime(
                            widget.selectedDate.year,
                            widget.selectedDate.month,
                            widget.selectedDate.day,
                            _selectedTime?.hour ?? TimeOfDay.now().hour,
                            _selectedTime?.minute ?? TimeOfDay.now().minute,
                          );
                          final durationText = _durationController.text.trim();
                          final duration = durationText.isEmpty
                              ? 0
                              : (int.tryParse(durationText) ?? 0);

                          Navigator.of(context).pop({
                            'dateTime': selectedDateTime,
                            'duration': duration,
                          });
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _selectTime(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacityValue(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: dmSans,
                          // Bumped 0.6 → 0.75 so this caption
                          // clears WCAG AA 4.5:1 over the card
                          // surface in light mode (blended text
                          // was ~4.2:1 at 0.6).
                          color: theme.colorScheme.onSurface
                              .withOpacityValue(0.75),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : l10n.selectTime,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          color: theme.colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacityValue(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
