import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:intl/intl.dart';

/// Confirmation dialog for adding a session to every day in a selected range.
///
/// Pops with `int` minutes-per-day on confirm, or `null` on cancel.
class BulkAddSessionsDialog extends StatefulWidget {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int dayCount;
  final int newSessionsCount;
  final int currentStreak;
  final int projectedStreak;

  const BulkAddSessionsDialog({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dayCount,
    required this.newSessionsCount,
    required this.currentStreak,
    required this.projectedStreak,
  });

  @override
  State<BulkAddSessionsDialog> createState() => _BulkAddSessionsDialogState();
}

class _BulkAddSessionsDialogState extends State<BulkAddSessionsDialog> {
  final TextEditingController _durationController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFmt = DateFormat('MMM d, y');
    final alreadyFilled = widget.dayCount - widget.newSessionsCount;
    final streakChanged = widget.projectedStreak != widget.currentStreak;

    return MeditoDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeditoDialogTitle(l10n.addSessionsTitle(widget.newSessionsCount)),
          const SizedBox(height: 12),
          MeditoDialogBody(
            '${dateFmt.format(widget.rangeStart)} – ${dateFmt.format(widget.rangeEnd)}',
          ),
          if (alreadyFilled > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.daysAlreadyHaveSession(alreadyFilled, widget.dayCount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: dmSans,
                color: theme.colorScheme.onSurface.withOpacityValue(0.7),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.brandPurple.withOpacityValue(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StreakRow(
                  label: l10n.currentStreak,
                  value:
                      '${widget.currentStreak} ${widget.currentStreak == 1 ? l10n.day.toLowerCase() : l10n.days}',
                ),
                const SizedBox(height: 6),
                _StreakRow(
                  label: l10n.newStreak,
                  value:
                      '${widget.projectedStreak} ${widget.projectedStreak == 1 ? l10n.day.toLowerCase() : l10n.days}',
                  emphasize: streakChanged,
                ),
                const SizedBox(height: 6),
                _StreakRow(
                  label: l10n.newSessions,
                  value: '${widget.newSessionsCount}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MeditoDialogTextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            labelText: l10n.minutesPerDayOptional,
            hintText: l10n.minutes,
            prefixIcon: Icon(Icons.timer, color: theme.colorScheme.onSurface),
          ),
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
                  label: '${l10n.add} ${widget.newSessionsCount}',
                  onPressed: widget.newSessionsCount == 0
                      ? null
                      : () {
                          final text = _durationController.text.trim();
                          final duration = text.isEmpty
                              ? 0
                              : (int.tryParse(text) ?? 0);
                          Navigator.of(context).pop(duration);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _StreakRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: dmSans,
            color: theme.colorScheme.onSurface.withOpacityValue(0.75),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: dmSans,
            fontWeight: FontWeight.w700,
            color: emphasize
                ? context.brandPurple
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
