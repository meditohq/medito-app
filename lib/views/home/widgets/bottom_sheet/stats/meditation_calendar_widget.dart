import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/day_boundary_offset_provider.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/calendar_range.dart';
import 'package:medito/utils/day_boundary.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'bulk_add_sessions_dialog.dart';
import 'manual_session_dialog.dart';

class MeditationCalendarWidget extends ConsumerStatefulWidget {
  final LocalAllStats stats;

  const MeditationCalendarWidget({super.key, required this.stats});

  @override
  ConsumerState<MeditationCalendarWidget> createState() =>
      _MeditationCalendarWidgetState();
}

class _MeditationCalendarWidgetState
    extends ConsumerState<MeditationCalendarWidget>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late DateTime _selectedDayForSessions;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isAddingSession = false;

  // Range selection: long-press one day to anchor, long-press a second day
  // to complete the range. A third long-press resets to a new anchor.
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    _focusedDay = today;
    _selectedDay = today;
    _selectedDayForSessions = todayStart;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSelectToday();
    });
  }

  void _checkAndSelectToday() {
    if (!mounted) return;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    setState(() {
      _selectedDayForSessions = todayStart;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// The user's configured day-boundary offset. MUST match the one
  /// `StatsManager.calculateStreak`/`calculateConsistencyScore` use, otherwise
  /// the calendar dots disagree with the streak for users who meditate inside
  /// the offset window (e.g. just after midnight with a "day starts at 3am"
  /// setting) — a session gets circled on one day but counted on another.
  Duration get _dayOffset {
    final hours = ref.read(dayBoundaryOffsetProvider).valueOrNull ?? 0;
    return Duration(hours: hours);
  }

  Set<DateTime> _getMeditationDates(LocalAllStats stats) {
    final dates = <DateTime>{};
    final offset = _dayOffset;
    final todayStart = dayOf(DateTime.now(), offset);

    if (stats.audioCompleted != null && stats.audioCompleted!.isNotEmpty) {
      for (final audio in stats.audioCompleted!) {
        if (isFreezeSession(audio)) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = dayOf(date, offset);
        if (!dayStart.isAfter(todayStart)) {
          dates.add(dayStart);
        }
      }
    }

    return dates;
  }

  Set<DateTime> _getFreezeDates(LocalAllStats stats) {
    final dates = <DateTime>{};
    final offset = _dayOffset;
    final todayStart = dayOf(DateTime.now(), offset);
    final meditationDates = _getMeditationDates(stats);

    // Legacy freeze dates stored in freezeUsageDates
    for (final timestamp in stats.freezeUsageDates) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dayStart = dayOf(date, offset);
      if (!dayStart.isAfter(todayStart) &&
          !meditationDates.contains(dayStart)) {
        dates.add(dayStart);
      }
    }

    // New freeze entries stored in audioCompleted
    if (stats.audioCompleted != null) {
      for (final audio in stats.audioCompleted!) {
        if (!isFreezeSession(audio)) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = dayOf(date, offset);
        if (!dayStart.isAfter(todayStart) &&
            !meditationDates.contains(dayStart)) {
          dates.add(dayStart);
        }
      }
    }

    return dates;
  }

  bool _isFreezeDay(DateTime day) {
    final freezeDates = _getFreezeDates(widget.stats);
    final dayStart = DateTime(day.year, day.month, day.day);

    return freezeDates.contains(dayStart);
  }

  List<LocalAudioCompleted> _getSessionsForDay(DateTime day) {
    final sessions = <LocalAudioCompleted>[];
    final offset = _dayOffset;
    // A cell represents the logical day `dayStart`; a session belongs to it
    // when `dayOf(session, offset)` lands on that same logical day.
    final dayStart = DateTime(day.year, day.month, day.day);

    if (widget.stats.audioCompleted != null &&
        widget.stats.audioCompleted!.isNotEmpty) {
      sessions.addAll(
        widget.stats.audioCompleted!.where((audio) {
          if (isFreezeSession(audio)) return false;
          final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          return dayOf(date, offset).isAtSameMomentAs(dayStart);
        }),
      );
    }

    sessions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sessions;
  }

  void _toggleDaySessions(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);

    if (isSameDay(_selectedDayForSessions, dayStart)) {
      return;
    }

    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedDayForSessions = dayStart;
        });
        _animationController.forward();
      }
    });
  }

  Future<void> _confirmDeleteSession(LocalAudioCompleted session) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => MeditoDialog(
        title: l10n.deleteSessionTitle,
        content: MeditoDialogBody(l10n.deleteSessionConfirmation),
        actions: [
          MeditoDialogSecondaryButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          MeditoDialogDestructiveButton(
            label: l10n.delete,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final errorMessage = l10n.deleteSessionError;

    final success = await deleteSession(session: session);

    if (!mounted) return;

    if (success) {
      await ref.read(statsProvider.notifier).refreshFromLocal();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  bool get _hasCompleteRange => _rangeStart != null && _rangeEnd != null;

  bool _isInRange(DateTime day) {
    if (!_hasCompleteRange) return false;
    final dayStart = DateTime(day.year, day.month, day.day);
    return !dayStart.isBefore(_rangeStart!) && !dayStart.isAfter(_rangeEnd!);
  }

  bool _isRangeEndpoint(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    return isSameDay(dayStart, _rangeStart) || isSameDay(dayStart, _rangeEnd);
  }

  List<DateTime> _datesInRange() {
    if (!_hasCompleteRange) return const [];
    return enumerateDays(_rangeStart!, _rangeEnd!);
  }

  void _handleLongPress(DateTime day) {
    final dayStart = startOfDay(day);
    final todayStart = startOfDay(DateTime.now());
    if (dayStart.isAfter(todayStart)) return;

    final next = expandRange(RangeBounds(_rangeStart, _rangeEnd), dayStart);
    if (next.start == _rangeStart && next.end == _rangeEnd) {
      return;
    }
    setState(() {
      _rangeStart = next.start;
      _rangeEnd = next.end;
    });
  }

  void _clearRange() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
    });
  }

  /// Raw session timestamps (not midnight-flattened) so the streak
  /// projection buckets them under the active day-boundary offset the same
  /// way [StatsManager.calculateStreak] will.
  List<DateTime> _getMeditationTimestamps(LocalAllStats stats) {
    final out = <DateTime>[];
    for (final audio in stats.audioCompleted ?? const <LocalAudioCompleted>[]) {
      if (isFreezeSession(audio)) continue;
      out.add(DateTime.fromMillisecondsSinceEpoch(audio.timestamp));
    }
    return out;
  }

  List<DateTime> _getFreezeTimestamps(LocalAllStats stats) {
    final out = <DateTime>[];
    for (final ts in stats.freezeUsageDates) {
      out.add(DateTime.fromMillisecondsSinceEpoch(ts));
    }
    for (final audio in stats.audioCompleted ?? const <LocalAudioCompleted>[]) {
      if (!isFreezeSession(audio)) continue;
      out.add(DateTime.fromMillisecondsSinceEpoch(audio.timestamp));
    }
    return out;
  }

  /// Shifts a calendar-picked midnight to the same hour the bulk-add helper
  /// will actually save it at, so the offset bucketing agrees.
  DateTime _anchorBulkAddDate(DateTime d) =>
      DateTime(d.year, d.month, d.day, manualSessionAnchorHour);

  int _projectedStreak(Iterable<DateTime> activityDates) {
    final hours = ref.read(dayBoundaryOffsetProvider).value ?? 0;
    return projectStreak(
      activityDates,
      DateTime.now(),
      dayBoundaryOffset: Duration(hours: hours),
    );
  }

  Future<void> _showBulkAddDialog(BuildContext context) async {
    if (!_hasCompleteRange) return;
    final dates = _datesInRange();

    final existing = <DateTime>{
      ..._getMeditationDates(widget.stats),
      ..._getFreezeDates(widget.stats),
    };
    final newSessionDays = dates.where((d) {
      final start = DateTime(d.year, d.month, d.day);
      return !existing.contains(start);
    }).toList();
    final projected = _projectedStreak([
      ..._getMeditationTimestamps(widget.stats),
      ..._getFreezeTimestamps(widget.stats),
      ...dates.map(_anchorBulkAddDate),
    ]);

    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => BulkAddSessionsDialog(
        rangeStart: _rangeStart!,
        rangeEnd: _rangeEnd!,
        dayCount: dates.length,
        newSessionsCount: newSessionDays.length,
        currentStreak: widget.stats.streakCurrent,
        projectedStreak: projected,
      ),
    );

    if (minutes == null || !mounted) return;

    setState(() {
      _isAddingSession = true;
    });

    final added = await addManualSessions(
      dates: newSessionDays,
      durationMinutes: minutes,
    );

    if (!mounted) return;

    setState(() {
      _isAddingSession = false;
      _rangeStart = null;
      _rangeEnd = null;
      if (added > 0) {
        _selectedDay = dates.last;
        _selectedDayForSessions = DateTime(
          dates.last.year,
          dates.last.month,
          dates.last.day,
        );
        _focusedDay = dates.last;
      }
    });
    _animationController.forward();
  }

  BulkSessionPreview _computeBulkPreview(DateTime start, DateTime end) {
    final dates = enumerateDays(start, end);
    final existing = <DateTime>{
      ..._getMeditationDates(widget.stats),
      ..._getFreezeDates(widget.stats),
    };
    final newSessions = dates.where((d) => !existing.contains(d)).length;
    final projected = _projectedStreak([
      ..._getMeditationTimestamps(widget.stats),
      ..._getFreezeTimestamps(widget.stats),
      ...dates.map(_anchorBulkAddDate),
    ]);
    return BulkSessionPreview(
      dayCount: dates.length,
      newSessionsCount: newSessions,
      currentStreak: widget.stats.streakCurrent,
      projectedStreak: projected,
    );
  }

  Future<void> _showAddSessionDialog(BuildContext context) async {
    final selectedDate = _selectedDayForSessions;

    final result = await showDialog<ManualSessionResult>(
      context: context,
      // The dialog has an explicit Cancel button; a barrier tap silently
      // discarding the user's input here looks like a successful add.
      barrierDismissible: false,
      builder: (context) => ManualSessionDialog(
        selectedDate: selectedDate,
        bulkPreviewBuilder: _computeBulkPreview,
      ),
    );

    if (result == null || !mounted) return;

    switch (result) {
      case ManualSessionSingleResult(:final dateTime, :final duration):
        setState(() {
          _isAddingSession = true;
          final dayStart = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
          );
          _selectedDayForSessions = dayStart;
          _selectedDay = dayStart;
          _focusedDay = dayStart;
        });
        _animationController.forward();

        final success = await addManualSession(
          dateTime: dateTime,
          durationMinutes: duration,
        );

        if (success && mounted) {
          await ref.read(statsProvider.notifier).refreshFromLocal();
        }

        if (mounted) {
          setState(() {
            _isAddingSession = false;
          });
        }
      case ManualSessionBulkResult(
        :final rangeStart,
        :final rangeEnd,
        :final duration,
      ):
        final dates = enumerateDays(rangeStart, rangeEnd);
        final existing = <DateTime>{
          ..._getMeditationDates(widget.stats),
          ..._getFreezeDates(widget.stats),
        };
        final newSessionDays = dates
            .where((d) => !existing.contains(d))
            .toList();

        setState(() {
          _isAddingSession = true;
        });

        await addManualSessions(
          dates: newSessionDays,
          durationMinutes: duration,
        );

        if (!mounted) return;

        await ref.read(statsProvider.notifier).refreshFromLocal();

        if (!mounted) return;

        setState(() {
          _isAddingSession = false;
          final last = dates.isNotEmpty ? dates.last : rangeEnd;
          _selectedDay = last;
          _selectedDayForSessions = DateTime(last.year, last.month, last.day);
          _focusedDay = last;
        });
        _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meditationDates = _getMeditationDates(widget.stats);
    final freezeDates = _getFreezeDates(widget.stats);
    final sessions = _getSessionsForDay(_selectedDayForSessions);
    final rangeDays = _datesInRange();
    final rangeNewSessions = _hasCompleteRange
        ? rangeDays.where((d) {
            final s = DateTime(d.year, d.month, d.day);
            return !meditationDates.contains(s) && !freezeDates.contains(s);
          }).length
        : 0;
    final rangeProjectedStreak = _hasCompleteRange
        ? _projectedStreak([
            ..._getMeditationTimestamps(widget.stats),
            ..._getFreezeTimestamps(widget.stats),
            ...rangeDays.map(_anchorBulkAddDate),
          ])
        : widget.stats.streakCurrent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCalendarCard(
          context,
          meditationDates: meditationDates,
          freezeDates: freezeDates,
        ),
        _buildDayDetailsCard(
          context,
          sessions: sessions,
          rangeDays: rangeDays,
          rangeNewSessions: rangeNewSessions,
          rangeProjectedStreak: rangeProjectedStreak,
        ),
      ],
    );
  }

  Widget _buildCalendarCard(
    BuildContext context, {
    required Set<DateTime> meditationDates,
    required Set<DateTime> freezeDates,
  }) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: TableCalendar<dynamic>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.now(),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) {
          // While a range is active, only range endpoints get selected styling.
          if (_rangeStart != null) return _isRangeEndpoint(day);
          return isSameDay(_selectedDay, day);
        },
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: _calendarHeaderStyle(context),
        calendarStyle: _calendarStyle(context),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, date, events) => _buildDefaultDayCell(
            context,
            date,
            meditationDates: meditationDates,
            freezeDates: freezeDates,
          ),
          todayBuilder: (context, date, events) => _buildTodayDayCell(
            context,
            date,
            meditationDates: meditationDates,
            freezeDates: freezeDates,
          ),
          selectedBuilder: (context, date, events) =>
              _buildSelectedDayCell(context, date, freezeDates: freezeDates),
        ),
        daysOfWeekStyle: _daysOfWeekStyle(context),
        onDaySelected: _onDaySelected,
        onDayLongPressed: (day, focusedDay) => _handleLongPress(day),
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  HeaderStyle _calendarHeaderStyle(BuildContext context) {
    final theme = Theme.of(context);
    return HeaderStyle(
      formatButtonVisible: false,
      titleCentered: true,
      titleTextStyle:
          theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
          ) ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: dmSans,
            color: theme.colorScheme.onSurface,
          ),
      leftChevronIcon: MeditoIcon(
        assetName: MeditoIcons.arrowLeft,
        size: 20,
        color: theme.colorScheme.onSurface,
      ),
      rightChevronIcon: MeditoIcon(
        assetName: MeditoIcons.arrowRight,
        size: 20,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  CalendarStyle _calendarStyle(BuildContext context) {
    return CalendarStyle(
      outsideDaysVisible: false,
      weekendTextStyle: _dayTextStyle(context),
      defaultTextStyle: _dayTextStyle(context),
      selectedDecoration: BoxDecoration(
        color: context.brandPurple,
        shape: BoxShape.circle,
      ),
      todayTextStyle: _dayTextStyle(context, fontWeight: FontWeight.w600),
      todayDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: context.brandPurple, width: 2),
      ),
    );
  }

  DaysOfWeekStyle _daysOfWeekStyle(BuildContext context) {
    final style = (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
        .copyWith(
          fontFamily: dmSans,
          color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.6),
          fontSize: 12,
        );

    return DaysOfWeekStyle(weekdayStyle: style, weekendStyle: style);
  }

  Widget? _buildDefaultDayCell(
    BuildContext context,
    DateTime date, {
    required Set<DateTime> meditationDates,
    required Set<DateTime> freezeDates,
  }) {
    final dayStart = startOfDay(date);
    final hasMeditation = meditationDates.contains(dayStart);
    final hasFreeze = freezeDates.contains(dayStart);
    final inRange = _isInRange(date);

    if (inRange && !hasMeditation && !hasFreeze) {
      return _buildDayCircle(
        context,
        date,
        color: context.brandPurple.withOpacityValue(0.20),
      );
    }

    if (hasMeditation) {
      return _buildDayCircle(
        context,
        date,
        color: context.brandPurple.withOpacityValue(inRange ? 0.32 : 0.15),
        fontWeight: FontWeight.w600,
      );
    }

    if (hasFreeze) {
      return _buildDayCircle(
        context,
        date,
        color: ColorConstants.lightBlue.withOpacityValue(inRange ? 0.32 : 0.15),
        fontWeight: FontWeight.w600,
      );
    }

    return null;
  }

  Widget _buildTodayDayCell(
    BuildContext context,
    DateTime date, {
    required Set<DateTime> meditationDates,
    required Set<DateTime> freezeDates,
  }) {
    final dayStart = startOfDay(date);
    final hasMeditation = meditationDates.contains(dayStart);
    final hasFreeze = freezeDates.contains(dayStart);
    final backgroundColor = hasMeditation
        ? context.brandPurple.withOpacityValue(0.25)
        : hasFreeze
        ? ColorConstants.lightBlue.withOpacityValue(0.25)
        : Theme.of(context).colorScheme.surface;

    return _buildDayCircle(
      context,
      date,
      color: backgroundColor,
      fontWeight: FontWeight.w600,
      border: Border.all(color: context.brandPurple, width: 2),
    );
  }

  Widget _buildSelectedDayCell(
    BuildContext context,
    DateTime date, {
    required Set<DateTime> freezeDates,
  }) {
    final dayStart = startOfDay(date);
    final fillColor = freezeDates.contains(dayStart)
        ? ColorConstants.lightBlue
        : context.brandPurple;

    if (_isRangeEndpoint(date)) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: fillColor.withOpacityValue(0.30),
          shape: BoxShape.circle,
        ),
        child: _buildDayCircle(
          context,
          date,
          color: fillColor,
          margin: const EdgeInsets.all(3),
          textColor: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return _buildDayCircle(
      context,
      date,
      color: fillColor,
      textColor: Theme.of(context).colorScheme.onPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  Widget _buildDayCircle(
    BuildContext context,
    DateTime date, {
    required Color color,
    EdgeInsets margin = const EdgeInsets.all(4),
    Color? textColor,
    FontWeight? fontWeight,
    BoxBorder? border,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: _dayTextStyle(
            context,
            color: textColor,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  TextStyle _dayTextStyle(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontFamily: dmSans,
      color: color ?? theme.colorScheme.onSurface,
      fontWeight: fontWeight,
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // A regular tap dismisses any in-progress range and behaves like
    // single-day selection.
    if (_rangeStart != null) {
      _clearRange();
    }
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _toggleDaySessions(selectedDay);
  }

  Widget _buildDayDetailsCard(
    BuildContext context, {
    required List<LocalAudioCompleted> sessions,
    required List<DateTime> rangeDays,
    required int rangeNewSessions,
    required int rangeProjectedStreak,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: _cardDecoration(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailsTitle(context, rangeDays),
            const SizedBox(height: 8),
            _buildDetailsSubtitle(context, sessions),
            const SizedBox(height: 16),
            _buildSessionList(context, sessions),
            const SizedBox(height: 16),
            _hasCompleteRange
                ? _buildRangeActions(
                    context,
                    rangeNewSessions: rangeNewSessions,
                    rangeProjectedStreak: rangeProjectedStreak,
                  )
                : _buildAddSessionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTitle(BuildContext context, List<DateTime> rangeDays) {
    return Text(
      _hasCompleteRange
          ? AppLocalizations.of(context)!.daysSelected(rangeDays.length)
          : DateFormat('EEEE, MMMM d, y').format(_selectedDayForSessions),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontFamily: dmSans,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildDetailsSubtitle(
    BuildContext context,
    List<LocalAudioCompleted> sessions,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (_hasCompleteRange) {
      return Text(
        '${DateFormat('MMM d').format(_rangeStart!)} – ${DateFormat('MMM d, y').format(_rangeEnd!)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: dmSans,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    if (_isFreezeDay(_selectedDayForSessions)) {
      return Row(
        children: [
          MeditoIcon(
            assetName: MeditoIcons.snow,
            size: 16,
            color: ColorConstants.lightBlue,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.streakFreezeUsed,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: dmSans,
              color: ColorConstants.lightBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      '${sessions.length} ${sessions.length == 1 ? l10n.session : l10n.sessions}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: dmSans,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    List<LocalAudioCompleted> sessions,
  ) {
    if (_isAddingSession) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: context.brandPurple),
        ),
      );
    }

    if (_hasCompleteRange || sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sessions.asMap().entries.map((entry) {
        final index = entry.key;
        final session = entry.value;
        final isLast = index == sessions.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: _SessionItemWidget(
            key: ValueKey(session.id + session.timestamp.toString()),
            session: session,
            onLongPress: () => _confirmDeleteSession(session),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRangeActions(
    BuildContext context, {
    required int rangeNewSessions,
    required int rangeProjectedStreak,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabel = widget.stats.streakCurrent == 1
        ? l10n.day.toLowerCase()
        : l10n.days;
    final projectedDayLabel = rangeProjectedStreak == 1
        ? l10n.day.toLowerCase()
        : l10n.days;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.brandPurple.withOpacityValue(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RangePreviewRow(
                label: l10n.currentStreak,
                value: '${widget.stats.streakCurrent} $dayLabel',
              ),
              const SizedBox(height: 6),
              _RangePreviewRow(
                label: l10n.newStreak,
                value: '$rangeProjectedStreak $projectedDayLabel',
                emphasize: rangeProjectedStreak != widget.stats.streakCurrent,
              ),
              const SizedBox(height: 6),
              _RangePreviewRow(
                label: l10n.newSessions,
                value: '$rangeNewSessions',
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isAddingSession || rangeNewSessions == 0
                ? null
                : () => _showBulkAddDialog(context),
            icon: Icon(
              Icons.add,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            label: Text(
              l10n.addSessionsToSelectedDays,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: dmSans,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: context.brandPurple),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isAddingSession ? null : _clearRange,
            child: Text(
              l10n.cancel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: dmSans,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacityValue(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddSessionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAddSessionDialog(context),
        icon: Icon(
          Icons.add,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        label: Text(
          AppLocalizations.of(context)!.addSession,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: dmSans,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacityValue(0.2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.08),
        width: 1,
      ),
    );
  }
}

class _SessionItemWidget extends ConsumerWidget {
  final LocalAudioCompleted session;
  final VoidCallback? onLongPress;

  const _SessionItemWidget({
    super.key,
    required this.session,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.fromMillisecondsSinceEpoch(session.timestamp);
    final timeFormat = DateFormat('h:mm a');
    final isManual = isManualSession(session);
    final trackAsync = isManual
        ? null
        : ref.watch(tracksProvider(trackId: session.id));

    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeFormat.format(date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: dmSans,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacityValue(0.7),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isManual ? ColorConstants.graphite : context.brandPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isManual
                ? Text(
                    getManualSessionTitle(
                      session.id,
                      AppLocalizations.of(context)!,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: dmSans,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : trackAsync!.when(
                    data: (track) => Text(
                      track.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: dmSans,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    loading: () => Text(
                      'Loading...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: dmSans,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    error: (_, _) => Text(
                      'Track ${session.id}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: dmSans,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
          ),
          if (!isManual)
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacityValue(0.6),
              size: 20,
            ),
        ],
      ),
    );

    if (isManual) {
      return InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackView(trackId: session.id),
          ),
        );
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _RangePreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _RangePreviewRow({
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
