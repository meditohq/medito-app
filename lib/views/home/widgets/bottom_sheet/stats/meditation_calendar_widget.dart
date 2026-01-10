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
import 'package:medito/widgets/medito_huge_icon.dart';
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
  DateTime? _selectedDayForSessions;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isAddingSession = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
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
    final sessions = _getSessionsForDay(todayStart);

    if (sessions.isNotEmpty) {
      setState(() {
        _selectedDayForSessions = todayStart;
      });
      _animationController.forward();
    }
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

    // Add real data
    if (stats.audioCompleted != null && stats.audioCompleted!.isNotEmpty) {
      for (final audio in stats.audioCompleted!) {
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = DateTime(date.year, date.month, date.day);

        if (!dayStart.isAfter(todayStart)) {
          dates.add(dayStart);
        }
      }
    }

    return dates;
  }

  List<LocalAudioCompleted> _getSessionsForDay(DateTime day) {
    final sessions = <LocalAudioCompleted>[];
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Add real sessions
    if (widget.stats.audioCompleted != null &&
        widget.stats.audioCompleted!.isNotEmpty) {
      sessions.addAll(widget.stats.audioCompleted!.where((audio) {
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        return date
                .isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
            date.isBefore(dayEnd);
      }));
    }

    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sessions;
  }

  void _toggleDaySessions(DateTime day) {
    if (_selectedDayForSessions != null &&
        isSameDay(_selectedDayForSessions!, day)) {
      // Hide if same day is tapped again
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _selectedDayForSessions = null;
          });
        }
      });
    } else {
      // Fade out current, then fade in new (always show container, even if no sessions)
      if (_selectedDayForSessions != null) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _selectedDayForSessions = day;
            });
            _animationController.forward();
          }
        });
      } else {
        // No current selection, just fade in
        setState(() {
          _selectedDayForSessions = day;
        });
        _animationController.forward();
      }
    }
  }

  Future<void> _showAddSessionDialog(BuildContext context) async {
    final selectedDate = _selectedDayForSessions ?? _selectedDay;

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
        ref: ref,
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
    final sessions = _selectedDayForSessions != null
        ? _getSessionsForDay(_selectedDayForSessions!)
        : <LocalAudioCompleted>[];

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
                color: ColorConstants.lightPurple,
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
                  color: ColorConstants.lightPurple,
                  width: 2,
                ),
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, events) {
                final dayStart = DateTime(date.year, date.month, date.day);
                final hasMeditation = meditationDates.contains(dayStart);

                if (hasMeditation) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColorConstants.lightPurple.withOpacityValue(0.15),
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

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasMeditation
                        ? ColorConstants.lightPurple.withOpacityValue(0.25)
                        : Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ColorConstants.lightPurple,
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
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ColorConstants.lightPurple,
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
        _selectedDayForSessions != null
            ? FadeTransition(
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
                        DateFormat('EEEE, MMMM d, y')
                            .format(_selectedDayForSessions!),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFamily: dmSans,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
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
                              color: ColorConstants.lightPurple,
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
                              key: ValueKey(
                                  session.id + session.timestamp.toString()),
                              session: session,
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontFamily: dmSans,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
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
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}

class _SessionItemWidget extends ConsumerWidget {
  final LocalAudioCompleted session;

  const _SessionItemWidget({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.fromMillisecondsSinceEpoch(session.timestamp);
    final timeFormat = DateFormat('HH:mm');
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
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isManual
                  ? ColorConstants.graphite
                  : ColorConstants.lightPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isManual
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: dmSans,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        loading: () => Text(
                          'Loading...',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: dmSans,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        error: (_, __) => Text(
                          'Track ${session.id}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: dmSans,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalizations.of(context)!.completedAt} ${timeFormat.format(date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: dmSans,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
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
      return content;
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
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}
