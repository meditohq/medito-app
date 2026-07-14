import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

/// Streak/session preview for a chosen date range, computed by the caller so
/// the dialog stays free of stats wiring.
class BulkSessionPreview {
  final int dayCount;
  final int newSessionsCount;
  final int currentStreak;
  final int projectedStreak;

  const BulkSessionPreview({
    required this.dayCount,
    required this.newSessionsCount,
    required this.currentStreak,
    required this.projectedStreak,
  });
}

typedef BulkPreviewBuilder =
    BulkSessionPreview Function(DateTime start, DateTime end);

/// Result returned from [ManualSessionDialog]. Pops with `null` on cancel,
/// otherwise either a [ManualSessionSingleResult] or [ManualSessionBulkResult].
sealed class ManualSessionResult {
  const ManualSessionResult();
}

class ManualSessionSingleResult extends ManualSessionResult {
  final DateTime dateTime;
  final int duration;

  const ManualSessionSingleResult({
    required this.dateTime,
    required this.duration,
  });
}

class ManualSessionBulkResult extends ManualSessionResult {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int duration;

  const ManualSessionBulkResult({
    required this.rangeStart,
    required this.rangeEnd,
    required this.duration,
  });
}

class ManualSessionDialog extends StatefulWidget {
  final DateTime selectedDate;

  /// When non-null, the dialog exposes a "Date range" tab and uses this to
  /// render the live streak/session preview for the chosen range.
  final BulkPreviewBuilder? bulkPreviewBuilder;

  const ManualSessionDialog({
    super.key,
    required this.selectedDate,
    this.bulkPreviewBuilder,
  });

  @override
  State<ManualSessionDialog> createState() => _ManualSessionDialogState();
}

class _ManualSessionDialogState extends State<ManualSessionDialog>
    with SingleTickerProviderStateMixin {
  TimeOfDay? _selectedTime;
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _bulkDurationController = TextEditingController();

  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  TabController? _tabController;

  bool get _hasBulkTab => widget.bulkPreviewBuilder != null;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    _rangeEnd = todayStart;
    _rangeStart = todayStart.subtract(const Duration(days: 6));

    if (_hasBulkTab) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _bulkDurationController.dispose();
    _tabController?.dispose();
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

  bool get _rangeOrderValid => !_rangeEnd.isBefore(_rangeStart);

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectRangeDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final initial = isStart ? _rangeStart : _rangeEnd;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: todayStart,
    );

    if (picked == null) return;
    final pickedStart = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (isStart) {
        _rangeStart = pickedStart;
        if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = _rangeStart;
      } else {
        _rangeEnd = pickedStart;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MeditoDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeditoDialogTitle(l10n.addSession),
          if (_hasBulkTab) ...[
            const SizedBox(height: 16),
            _buildTabBar(context, l10n),
          ],
          const SizedBox(height: 16),
          if (!_hasBulkTab)
            _buildSingleTab(context, l10n)
          else if (_tabController!.index == 0)
            _buildSingleTab(context, l10n)
          else
            _buildBulkTab(context, l10n),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(child: _buildTabItem(0, l10n.singleDay)),
        Expanded(child: _buildTabItem(1, l10n.dateRange)),
      ],
    );
  }

  Widget _buildTabItem(int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _tabController!.index == index;
    final selectedColor = theme.colorScheme.onSurface;
    final unselectedColor = theme.colorScheme.onSurface.withOpacityValue(0.5);

    return InkWell(
      onTap: () => _tabController!.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacityValue(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: dmSans,
              color: isSelected ? selectedColor : unselectedColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleTab(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          prefixIcon: Icon(Icons.timer, color: theme.colorScheme.onSurface),
          suffixIcon: _durationController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacityValue(0.6),
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
                onPressed: _isFutureSession() ? null : _submitSingle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulkTab(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final preview = _rangeOrderValid
        ? widget.bulkPreviewBuilder!(_rangeStart, _rangeEnd)
        : null;
    final streakChanged =
        preview != null && preview.projectedStreak != preview.currentStreak;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDatePickerTile(
                context,
                label: l10n.startDate,
                value: _rangeStart,
                onTap: () => _selectRangeDate(context, isStart: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDatePickerTile(
                context,
                label: l10n.endDate,
                value: _rangeEnd,
                onTap: () => _selectRangeDate(context, isStart: false),
              ),
            ),
          ],
        ),
        if (!_rangeOrderValid) ...[
          const SizedBox(height: 12),
          Text(
            l10n.endDateBeforeStartError,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: dmSans,
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (preview != null) ...[
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
                _PreviewRow(
                  label: l10n.currentStreak,
                  value:
                      '${preview.currentStreak} ${preview.currentStreak == 1 ? l10n.day.toLowerCase() : l10n.days}',
                ),
                const SizedBox(height: 6),
                _PreviewRow(
                  label: l10n.newStreak,
                  value:
                      '${preview.projectedStreak} ${preview.projectedStreak == 1 ? l10n.day.toLowerCase() : l10n.days}',
                  emphasize: streakChanged,
                ),
                const SizedBox(height: 6),
                _PreviewRow(
                  label: l10n.newSessions,
                  value: '${preview.newSessionsCount}',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        MeditoDialogTextField(
          controller: _bulkDurationController,
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
                label: preview != null && preview.newSessionsCount > 0
                    ? '${l10n.add} ${preview.newSessionsCount}'
                    : l10n.add,
                onPressed: (preview == null || preview.newSessionsCount == 0)
                    ? null
                    : _submitBulk,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submitSingle() {
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

    Navigator.of(context).pop(
      ManualSessionSingleResult(dateTime: selectedDateTime, duration: duration),
    );
  }

  void _submitBulk() {
    final text = _bulkDurationController.text.trim();
    final duration = text.isEmpty ? 0 : (int.tryParse(text) ?? 0);
    Navigator.of(context).pop(
      ManualSessionBulkResult(
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        duration: duration,
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
                      color: theme.colorScheme.onSurface.withOpacityValue(0.75),
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

  Widget _buildDatePickerTile(
    BuildContext context, {
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, y');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacityValue(0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: dmSans,
                color: theme.colorScheme.onSurface.withOpacityValue(0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fmt.format(value),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: dmSans,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _PreviewRow({
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
