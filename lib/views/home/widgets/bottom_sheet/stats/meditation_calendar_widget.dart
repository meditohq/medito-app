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

  const MeditationCalendarWidget({
    super.key,
    required this.stats,
  });

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

  Set<DateTime> _getMeditationDates(LocalAllStats stats) {
    final dates = <DateTime>{};
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    if (stats.audioCompleted != null && stats.audioCompleted!.isNotEmpty) {
      for (final audio in stats.audioCompleted!) {
        if (isFreezeSession(audio)) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = DateTime(date.year, date.month, date.day);
        if (!dayStart.isAfter(todayStart)) {
          dates.add(dayStart);
        }
      }
    }

    return dates;
  }

  Set<DateTime> _getFreezeDates(LocalAllStats stats) {
    final dates = <DateTime>{};
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final meditationDates = _getMeditationDates(stats);

    // Legacy freeze dates stored in freezeUsageDates
    for (final timestamp in stats.freezeUsageDates) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dayStart = DateTime(date.year, date.month, date.day);
      if (!dayStart.isAfter(todayStart) && !meditationDates.contains(dayStart)) {
        dates.add(dayStart);
      }
    }

    // New freeze entries stored in audioCompleted
    if (stats.audioCompleted != null) {
      for (final audio in stats.audioCompleted!) {
        if (!isFreezeSession(audio)) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = DateTime(date.year, date.month, date.day);
        if (!dayStart.isAfter(todayStart) && !meditationDates.contains(dayStart)) {
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
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    if (widget.stats.audioCompleted != null &&
        widget.stats.audioCompleted!.isNotEmpty) {
      sessions.addAll(widget.stats.audioCompleted!.where((audio) {
        if (isFreezeSession(audio)) return false;
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        return date
                .isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(dayEnd);
      }));
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
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
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
        _selectedDayForSessions =
            DateTime(dates.last.year, dates.last.month, dates.last.day);
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
          final dayStart =
              DateTime(dateTime.year, dateTime.month, dateTime.day);
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
        final newSessionDays =
            dates.where((d) => !existing.contains(d)).toList();

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
          _selectedDayForSessions =
              DateTime(last.year, last.month, last.day);
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
    final isSelectedDayFreezeDay = _isFreezeDay(_selectedDayForSessions);
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
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacityValue(0.08),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: TableCalendar<dynamic>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              // While a range (partial or complete) is active, only the
              // range endpoints get the "selected" treatment — the previous
              // single-tap selection should appear deselected.
              if (_rangeStart != null) return _isRangeEndpoint(day);
              return isSameDay(_selectedDay, day);
            },
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: dmSans,
                      ) ??
                  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: dmSans,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              leftChevronIcon: MeditoIcon(
                assetName: MeditoIcons.arrowLeft,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              rightChevronIcon: MeditoIcon(
                assetName: MeditoIcons.arrowRight,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: dmSans,
                            color: Theme.of(context).colorScheme.onSurface,
                          ) ??
                      TextStyle(
                        fontFamily: dmSans,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
              defaultTextStyle:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: dmSans,
                            color: Theme.of(context).colorScheme.onSurface,
                          ) ??
                      TextStyle(
                        fontFamily: dmSans,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
              selectedDecoration: BoxDecoration(
                color: context.brandPurple,
                shape: BoxShape.circle,
              ),
              todayTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: dmSans,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ) ??
                  TextStyle(
                    fontFamily: dmSans,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.brandPurple,
                  width: 2,
                ),
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, events) {
                final dayStart = DateTime(date.year, date.month, date.day);
                final hasMeditation = meditationDates.contains(dayStart);
                final hasFreeze = freezeDates.contains(dayStart);
                final inRange = _isInRange(date);

                if (inRange && !hasMeditation && !hasFreeze) {
                  // Bumped from 0.08 → 0.20 so the in-range band is clearly
                  // visible in both light and dark themes (0.08 disappeared
                  // against the dark surface).
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.brandPurple.withOpacityValue(0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  );
                }

                if (hasMeditation) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      // In-range meditation days get a deeper tint so the
                      // range band stays continuous across them.
                      color: context.brandPurple.withOpacityValue(
                        inRange ? 0.32 : 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                }

                if (hasFreeze) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColorConstants.lightBlue.withOpacityValue(
                        inRange ? 0.32 : 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                }

                return null;
              },
              todayBuilder: (context, date, events) {
                final dayStart = DateTime(date.year, date.month, date.day);
                final hasMeditation = meditationDates.contains(dayStart);
                final hasFreeze = freezeDates.contains(dayStart);

                Color backgroundColor;
                if (hasMeditation) {
                  backgroundColor = context.brandPurple.withOpacityValue(0.25);
                } else if (hasFreeze) {
                  backgroundColor = ColorConstants.lightBlue.withOpacityValue(0.25);
                } else {
                  backgroundColor = Theme.of(context).colorScheme.surface;
                }

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.brandPurple,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: dmSans,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                );
              },
              selectedBuilder: (context, date, events) {
                final dayStart = DateTime(date.year, date.month, date.day);
                final hasFreeze = freezeDates.contains(dayStart);
                final isEndpoint = _isRangeEndpoint(date);
                final fillColor =
                    hasFreeze ? ColorConstants.lightBlue : context.brandPurple;
                final dayText = Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: dmSans,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                );

                if (isEndpoint) {
                  // Range endpoints get a haloed solid circle so they read as
                  // clearly heavier than today, meditation days, or a regular
                  // tap-selected day. The translucent outer ring works in both
                  // light and dark modes because it's the brand colour over
                  // the surface, not a hardcoded shade.
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: fillColor.withOpacityValue(0.30),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: fillColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: dayText),
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: fillColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: dayText),
                );
              },
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: dmSans,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacityValue(0.6),
                        fontSize: 12,
                      ) ??
                  TextStyle(
                    fontFamily: dmSans,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacityValue(0.6),
                    fontSize: 12,
                  ),
              weekendStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: dmSans,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacityValue(0.6),
                        fontSize: 12,
                      ) ??
                  TextStyle(
                    fontFamily: dmSans,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacityValue(0.6),
                    fontSize: 12,
                  ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              // A regular tap dismisses any in-progress range and behaves
              // like single-day selection.
              if (_rangeStart != null) {
                _clearRange();
              }
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _toggleDaySessions(selectedDay);
            },
            onDayLongPressed: (day, focusedDay) {
              _handleLongPress(day);
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
        ),
        FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacityValue(0.08),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasCompleteRange
                      ? AppLocalizations.of(context)!
                          .daysSelected(rangeDays.length)
                      : DateFormat('EEEE, MMMM d, y')
                          .format(_selectedDayForSessions),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: dmSans,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                if (_hasCompleteRange)
                  Text(
                    '${DateFormat('MMM d').format(_rangeStart!)} – ${DateFormat('MMM d, y').format(_rangeEnd!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  )
                else if (isSelectedDayFreezeDay)
                  Row(
                    children: [
                      MeditoIcon(
                        assetName: MeditoIcons.snow,
                        size: 16,
                        color: ColorConstants.lightBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.streakFreezeUsed,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: ColorConstants.lightBlue,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${sessions.length} ${sessions.length == 1 ? AppLocalizations.of(context)!.session : AppLocalizations.of(context)!.sessions}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: dmSans,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                const SizedBox(height: 16),
                if (_isAddingSession)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.brandPurple,
                      ),
                    ),
                  )
                else if (_hasCompleteRange)
                  const SizedBox.shrink()
                else if (sessions.isNotEmpty)
                  ...sessions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final session = entry.value;
                    final isLast = index == sessions.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: _SessionItemWidget(
                        key:
                            ValueKey(session.id + session.timestamp.toString()),
                        session: session,
                        onLongPress: () => _confirmDeleteSession(session),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                if (_hasCompleteRange) ...[
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
                          label: AppLocalizations.of(context)!.currentStreak,
                          value:
                              '${widget.stats.streakCurrent} ${widget.stats.streakCurrent == 1 ? AppLocalizations.of(context)!.day.toLowerCase() : AppLocalizations.of(context)!.days}',
                        ),
                        const SizedBox(height: 6),
                        _RangePreviewRow(
                          label: AppLocalizations.of(context)!.newStreak,
                          value:
                              '$rangeProjectedStreak ${rangeProjectedStreak == 1 ? AppLocalizations.of(context)!.day.toLowerCase() : AppLocalizations.of(context)!.days}',
                          emphasize: rangeProjectedStreak !=
                              widget.stats.streakCurrent,
                        ),
                        const SizedBox(height: 6),
                        _RangePreviewRow(
                          label: AppLocalizations.of(context)!.newSessions,
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
                        AppLocalizations.of(context)!.addSessionsToSelectedDays,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(
                          color: context.brandPurple,
                        ),
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
                        AppLocalizations.of(context)!.cancel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: dmSans,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacityValue(0.7),
                            ),
                      ),
                    ),
                  ),
                ] else
                SizedBox(
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacityValue(0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final trackAsync =
        isManual ? null : ref.watch(tracksProvider(trackId: session.id));

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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacityValue(0.7),
                    fontSize: 12,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isManual
                  ? ColorConstants.graphite
                  : context.brandPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isManual
                ? Text(
                    getManualSessionTitle(
                        session.id, AppLocalizations.of(context)!),
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
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacityValue(0.6),
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
            builder: (context) => TrackView(
              trackId: session.id,
            ),
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
