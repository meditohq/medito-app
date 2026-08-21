// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart'
    show reminderProvider, smartBaseId;
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/services/history/app_history_service.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class _ReminderWithDate {
  final PendingNotificationRequest? reminder;
  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final DateTime? scheduledDate;

  _ReminderWithDate.fromReminder({
    required PendingNotificationRequest reminder,
    DateTime? scheduledDate,
  }) : reminder = reminder,
       id = reminder.id,
       title = reminder.title,
       body = reminder.body,
       payload = reminder.payload,
       scheduledDate = scheduledDate;

  _ReminderWithDate.calculated({
    required int id,
    required DateTime scheduledDate,
  }) : reminder = null,
       id = id,
       title = null,
       body = null,
       payload = scheduledDate.toIso8601String(),
       scheduledDate = scheduledDate;
}

class DebugInfoScreen extends ConsumerWidget {
  const DebugInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: HomeHeaderWidget(
          greeting: AppLocalizations.of(context)!.debugInfo,
        ),
      ),
      body: _buildBody(context, ref),
      bottomNavigationBar: _buildBottomBar(context, ref),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
              onLongPress: () => _openOnboardingFlow(context),
              tooltip: AppLocalizations.of(context)!.goBack,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _copyDebugInfo(context, ref),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(AppLocalizations.of(context)!.copy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ref
        .watch(deviceAppAndUserInfoProvider)
        .when(
          data: (infoString) => _buildInfoView(context, ref, infoString),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(AppLocalizations.of(context)!.anErrorOccurred),
          ),
        );
  }

  String _buildStatsBase64(WidgetRef ref) {
    final stats = ref.read(statsProvider).asData?.value;
    if (stats == null) return '';
    final bytes = utf8.encode(jsonEncode(stats.toJson()));
    return base64Encode(bytes);
  }

  Widget _buildInfoView(
    BuildContext context,
    WidgetRef ref,
    String infoString,
  ) {
    final fullInfo = infoString;
    final statsBase64 = _buildStatsBase64(ref);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            fullInfo,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (statsBase64.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Stats (base64)',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SelectableText(
              statsBase64,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _buildHistorySection(
            context,
            title: 'Installed Versions',
            body: _formatVersionHistory(ref),
            base64: AppHistoryService.getVersionHistoryBase64(
              ref.read(sharedPreferencesProvider),
            ),
            emptyText: 'No versions recorded yet',
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _buildHistorySection(
            context,
            title: 'Sign-In History',
            body: _formatSignInHistory(ref),
            base64: AppHistoryService.getSignInHistoryBase64(
              ref.read(sharedPreferencesProvider),
            ),
            emptyText: 'No sign-ins recorded yet',
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Pending Reminders',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPendingReminders(context, ref),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingReminders(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<_ReminderWithDate>>(
      future: _getPendingRemindersWithDates(ref),
      builder: (context, snapshot) {
        AppLogger.d(
          'DEBUG_INFO_SCREEN',
          'Pending reminders FutureBuilder state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          AppLogger.d('DEBUG_INFO_SCREEN', 'Loading pending reminders...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          AppLogger.e(
            'DEBUG_INFO_SCREEN',
            'Error loading reminders: ${snapshot.error}',
          );
          return Text(
            'Error loading reminders: ${snapshot.error}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          );
        }

        final reminders = snapshot.data ?? [];
        AppLogger.d(
          'DEBUG_INFO_SCREEN',
          'Received ${reminders.length} reminder(s)',
        );

        if (reminders.isEmpty) {
          AppLogger.d('DEBUG_INFO_SCREEN', 'No reminders found');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pending reminders',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: On Android, notifications scheduled with inexactAllowWhileIdle may not appear in pending notifications.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          );
        }

        AppLogger.d(
          'DEBUG_INFO_SCREEN',
          'Building list with ${reminders.length} reminder(s)',
        );

        final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
        final buffer = StringBuffer();
        buffer.writeln('Found ${reminders.length} pending reminder(s):');
        buffer.writeln();

        for (final reminderWithDate in reminders) {
          final scheduledDate = reminderWithDate.scheduledDate;

          AppLogger.d(
            'DEBUG_INFO_SCREEN',
            'Reminder ID: ${reminderWithDate.id}, Title: ${reminderWithDate.title}, Payload: ${reminderWithDate.payload}, ScheduledDate: $scheduledDate',
          );

          buffer.writeln('ID: ${reminderWithDate.id}');
          if (scheduledDate != null) {
            buffer.writeln('Scheduled: ${dateFormat.format(scheduledDate)}');
          }
          if (reminderWithDate.title != null &&
              reminderWithDate.title!.isNotEmpty) {
            buffer.writeln('Title: ${reminderWithDate.title}');
          }
          if (reminderWithDate.body != null &&
              reminderWithDate.body!.isNotEmpty) {
            buffer.writeln('Body: ${reminderWithDate.body}');
          }
          buffer.writeln();
        }

        return SelectableText(
          buffer.toString(),
          style: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }

  Future<List<_ReminderWithDate>> _getPendingRemindersWithDates(
    WidgetRef ref,
  ) async {
    AppLogger.d('REMINDERS', '_getPendingRemindersWithDates called');
    final reminders = await ref
        .read(reminderProvider)
        .getPendingNotifications();
    AppLogger.d(
      'REMINDERS',
      'Got ${reminders.length} pending notifications from system',
    );
    final prefs = ref.read(sharedPreferencesProvider);
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    final isReminderEnabled =
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
        (savedHour != null && savedMinute != null);

    AppLogger.d(
      'REMINDERS',
      'Reminder state: enabled=$isReminderEnabled, savedHour=$savedHour, savedMinute=$savedMinute',
    );

    for (final reminder in reminders) {
      AppLogger.d(
        'REMINDERS',
        'Pending reminder: ID=${reminder.id}, payload=${reminder.payload}, title=${reminder.title}',
      );
    }

    final result = reminders.map((reminder) {
      DateTime? scheduledDate;

      if (reminder.payload != null && reminder.payload!.isNotEmpty) {
        try {
          scheduledDate = DateTime.parse(reminder.payload!);
          AppLogger.d(
            'DEBUG_INFO_SCREEN',
            'Parsed scheduled date from payload: $scheduledDate',
          );
        } catch (e) {
          AppLogger.d(
            'DEBUG_INFO_SCREEN',
            'Failed to parse payload: ${reminder.payload}, error: $e',
          );
        }
      }

      if (scheduledDate == null &&
          reminder.id >= smartBaseId &&
          reminder.id <= smartBaseId + 15 &&
          savedHour != null &&
          savedMinute != null) {
        scheduledDate = _calculateScheduledDate(
          reminder.id,
          savedHour,
          savedMinute,
        );
      }

      return _ReminderWithDate.fromReminder(
        reminder: reminder,
        scheduledDate: scheduledDate,
      );
    }).toList();

    if (kDebugMode &&
        result.isEmpty &&
        isReminderEnabled &&
        savedHour != null &&
        savedMinute != null) {
      AppLogger.d(
        'REMINDERS',
        'Debug mode: No pending notifications but reminders enabled, adding calculated dates for UI',
      );
      final calculatedDates = await _getCalculatedScheduledDates(ref);
      for (final entry in calculatedDates) {
        result.add(
          _ReminderWithDate.calculated(
            id: entry.key,
            scheduledDate: entry.value,
          ),
        );
      }
    }

    return result;
  }

  Future<List<MapEntry<int, DateTime>>> _getCalculatedScheduledDates(
    WidgetRef ref,
  ) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    final isReminderEnabled =
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
        (savedHour != null && savedMinute != null);

    AppLogger.d(
      'DEBUG_INFO_SCREEN',
      'Calculated dates check: isReminderEnabled=$isReminderEnabled, savedHour=$savedHour, savedMinute=$savedMinute',
    );

    if (!isReminderEnabled || savedHour == null || savedMinute == null) {
      AppLogger.d(
        'DEBUG_INFO_SCREEN',
        'Skipping calculated dates: reminders not enabled or time not saved',
      );
      return [];
    }

    final result = <MapEntry<int, DateTime>>[];
    for (var i = 0; i <= 15; i++) {
      final reminderId = smartBaseId + i;
      final scheduledDate = _calculateScheduledDate(
        reminderId,
        savedHour,
        savedMinute,
      );
      result.add(MapEntry(reminderId, scheduledDate));
    }
    AppLogger.d(
      'DEBUG_INFO_SCREEN',
      'Calculated ${result.length} scheduled dates',
    );
    return result;
  }

  DateTime _calculateScheduledDate(
    int reminderId,
    int savedHour,
    int savedMinute,
  ) {
    final dayOffset = reminderId - smartBaseId;
    final now = DateTime.now();
    var anchor = DateTime(now.year, now.month, now.day, savedHour, savedMinute);
    if (anchor.isBefore(now)) {
      anchor = anchor.add(const Duration(days: 1));
    }
    final daysToAdd = dayOffset == 15 ? 29 : dayOffset;
    final scheduledDate = anchor.add(Duration(days: daysToAdd));
    AppLogger.d(
      'DEBUG_INFO_SCREEN',
      'Calculated scheduled date from ID $reminderId (day offset: $dayOffset, days to add: $daysToAdd): $scheduledDate',
    );
    return scheduledDate;
  }

  void _openOnboardingFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingPagerScreen()),
    );
  }

  Widget _buildHistorySection(
    BuildContext context, {
    required String title,
    required String body,
    required String base64,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        SelectableText(
          body.isEmpty ? emptyText : body,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (base64.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            base64,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  String _formatVersionHistory(WidgetRef ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final history = AppHistoryService.getVersionHistory(prefs);
    if (history.isEmpty) return '';
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return history
        .map((e) {
          final version = e['version'] ?? '';
          final build = e['buildNumber'] ?? '';
          final seen = _parseDateOrEmpty(e['firstSeenAt'], df);
          return '• $version ($build) — $seen';
        })
        .join('\n');
  }

  String _formatSignInHistory(WidgetRef ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final history = AppHistoryService.getSignInHistory(prefs);
    if (history.isEmpty) return '';
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return history
        .map((e) {
          final userId = e['userId'] ?? '';
          final email = (e['email'] as String?) ?? '';
          final at = _parseDateOrEmpty(e['signedInAt'], df);
          final emailPart = email.isEmpty ? '' : ' — $email';
          return '• $at\n  id: $userId$emailPart';
        })
        .join('\n');
  }

  String _parseDateOrEmpty(dynamic iso, DateFormat df) {
    if (iso is! String || iso.isEmpty) return '';
    try {
      return df.format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  void _copyDebugInfo(BuildContext context, WidgetRef ref) async {
    final infoString = await ref.read(deviceAppAndUserInfoProvider.future);
    var fullInfo = infoString;

    final reminders = await _getPendingRemindersWithDates(ref);
    final calculatedDates = await _getCalculatedScheduledDates(ref);

    AppLogger.d(
      'DEBUG_INFO_SCREEN',
      'Copy debug info: ${reminders.length} pending reminders, ${calculatedDates.length} calculated dates',
    );

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer();
    final addedIds = <int>{};

    if (reminders.isNotEmpty) {
      buffer.writeln('\nScheduled Events:');
      for (final reminderWithDate in reminders) {
        final scheduledDate = reminderWithDate.scheduledDate;
        if (scheduledDate != null) {
          buffer.writeln('Event ${reminderWithDate.id}');
          buffer.writeln('  Time: ${dateFormat.format(scheduledDate)}');
          addedIds.add(reminderWithDate.id);
        }
      }
    }

    if (calculatedDates.isNotEmpty) {
      if (buffer.isEmpty) {
        buffer.writeln('\nScheduled Events:');
      }
      for (final entry in calculatedDates) {
        if (!addedIds.contains(entry.key)) {
          buffer.writeln('Event ${entry.key}');
          buffer.writeln('  Time: ${dateFormat.format(entry.value)}');
        }
      }
    }

    if (buffer.isNotEmpty) {
      fullInfo = '$fullInfo$buffer';
      AppLogger.d('DEBUG_INFO_SCREEN', 'Added scheduled events to copy text');
    } else {
      AppLogger.d('DEBUG_INFO_SCREEN', 'No scheduled events to add');
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final versionHistoryB64 = AppHistoryService.getVersionHistoryBase64(prefs);
    if (versionHistoryB64.isNotEmpty) {
      fullInfo = '$fullInfo\n\nversion_history_b64: $versionHistoryB64';
    }

    final signInHistoryB64 = AppHistoryService.getSignInHistoryBase64(prefs);
    if (signInHistoryB64.isNotEmpty) {
      fullInfo = '$fullInfo\n\nsignin_history_b64: $signInHistoryB64';
    }

    // Surfaced in plaintext (not just inside stats_b64) so support can see the
    // user's day-boundary offset without decoding — it drives how the streak
    // buckets sessions into days.
    final dayBoundaryOffsetHours =
        prefs.getInt(SharedPreferenceConstants.dayBoundaryOffsetHours) ?? 0;
    fullInfo = '$fullInfo\n\ndayBoundaryOffsetHours: $dayBoundaryOffsetHours';

    final statsBase64 = _buildStatsBase64(ref);
    if (statsBase64.isNotEmpty) {
      fullInfo = '$fullInfo\n\nstats_b64: $statsBase64';
    }

    await Clipboard.setData(ClipboardData(text: fullInfo));
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.debugInfoCopied);
    }
  }
}
