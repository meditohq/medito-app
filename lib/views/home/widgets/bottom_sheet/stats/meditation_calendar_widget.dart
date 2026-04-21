import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/meditation/track_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/track/track_view.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
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

  Future<void> _showAddSessionDialog(BuildContext context) async {
    final selectedDate = _selectedDayForSessions;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ManualSessionDialog(selectedDate: selectedDate),
    );

    if (result != null && mounted) {
      final dateTime = result['dateTime'] as DateTime;
      final duration = result['duration'] as int;

      setState(() {
        _isAddingSession = true;
        final dayStart = DateTime(dateTime.year, dateTime.month, dateTime.day);
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
        // Refresh stats to update the calendar
        await ref.read(statsProvider.notifier).refreshFromLocal();
      }

      if (mounted) {
        setState(() {
          _isAddingSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meditationDates = _getMeditationDates(widget.stats);
    final freezeDates = _getFreezeDates(widget.stats);
    final sessions = _getSessionsForDay(_selectedDayForSessions);
    final isSelectedDayFreezeDay = _isFreezeDay(_selectedDayForSessions);

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
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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

                if (hasMeditation) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.brandPurple.withOpacityValue(0.15),
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
                      color: ColorConstants.lightBlue.withOpacityValue(0.15),
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

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasFreeze ? ColorConstants.lightBlue : context.brandPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: dmSans,
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
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
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _toggleDaySessions(selectedDay);
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
                  DateFormat('EEEE, MMMM d, y').format(_selectedDayForSessions),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: dmSans,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                if (isSelectedDayFreezeDay)
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
