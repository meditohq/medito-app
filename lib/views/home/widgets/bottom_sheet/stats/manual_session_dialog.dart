import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';

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
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ColorConstants.lightPurple,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
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

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addSession,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: dmSans,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.addSessionExplanation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: dmSans,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacityValue(0.7),
                  ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => _selectTime(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.time,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: dmSans,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacityValue(0.6),
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTime != null
                                ? _selectedTime!.format(context)
                                : l10n.selectTime,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontFamily: dmSans,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacityValue(0.6),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText:
                    '${l10n.duration} (in ${l10n.minutes.toLowerCase()}, ${l10n.optional.toLowerCase()})',
                hintText: l10n.minutes,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(
                  Icons.timer,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                suffixIcon: _durationController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacityValue(0.6),
                        ),
                        onPressed: () {
                          _durationController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: dmSans,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            if (_isFutureSession()) ...[
              const SizedBox(height: 12),
              Text(
                l10n.cannotAddFutureSession,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: dmSans,
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.cancel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
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
                  child: Text(
                    l10n.add,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
