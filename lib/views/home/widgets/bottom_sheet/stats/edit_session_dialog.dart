import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/constants/theme/medito_text.dart';

class EditSessionDialog extends StatefulWidget {
  const EditSessionDialog({super.key, required this.initialDate});
  final DateTime initialDate;

  @override
  State<EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<EditSessionDialog> {
  late DateTime _date = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isFuture = _date.isAfter(DateTime.now());
    return MeditoDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeditoDialogTitle(l10n.editSessionDateTime),
          const SizedBox(height: 12),
          MeditoDialogBody(l10n.editSessionExplanation),
          const SizedBox(height: 24),
          _EditableSessionField(
            icon: Icons.calendar_today_outlined,
            label: l10n.date,
            value: DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).format(_date),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(
                  () => _date = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    _date.hour,
                    _date.minute,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _EditableSessionField(
            icon: Icons.schedule_outlined,
            label: l10n.time,
            value: TimeOfDay.fromDateTime(_date).format(context),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_date),
              );
              if (picked != null && mounted) {
                setState(
                  () => _date = DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    picked.hour,
                    picked.minute,
                  ),
                );
              }
            },
          ),
          if (isFuture)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.cannotAddFutureSession,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MeditoDialogSecondaryButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MeditoDialogPrimaryButton(
                  label: l10n.save,
                  onPressed: isFuture
                      ? null
                      : () => Navigator.pop(context, _date),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableSessionField extends StatelessWidget {
  const _EditableSessionField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: context.text.caption.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: context.text.subtitle.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
