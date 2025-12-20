import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';

class _ReminderWithDate {
  final PendingNotificationRequest reminder;
  final DateTime? scheduledDate;

  _ReminderWithDate({
    required this.reminder,
    this.scheduledDate,
  });
}

class DebugInfoScreen extends ConsumerWidget {
  const DebugInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        title:
            HomeHeaderWidget(greeting: AppLocalizations.of(context)!.debugInfo),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyDebugInfo(context, ref),
            tooltip: AppLocalizations.of(context)!.copy,
          ),
        ],
      ),
      body: _buildBody(context, ref),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ref.watch(deviceAppAndUserInfoProvider).when(
          data: (infoString) => _buildInfoView(context, ref, infoString),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(AppLocalizations.of(context)!.anErrorOccurred),
          ),
        );
  }

  Widget _buildInfoView(
      BuildContext context, WidgetRef ref, String infoString) {
    final paywallManager = ref.read(paywallManagerServiceProvider);
    final donationPlacementId = paywallManager.getDonationPlacementId();
    final fullInfo = '$infoString\nDPI: $donationPlacementId';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            fullInfo,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Pending Reminders',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
        AppLogger.d('DEBUG_INFO_SCREEN',
            'Pending reminders FutureBuilder state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          AppLogger.d('DEBUG_INFO_SCREEN', 'Loading pending reminders...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          AppLogger.e('DEBUG_INFO_SCREEN',
              'Error loading reminders: ${snapshot.error}');
          return Text(
            'Error loading reminders: ${snapshot.error}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          );
        }

        final reminders = snapshot.data ?? [];
        AppLogger.d(
            'DEBUG_INFO_SCREEN', 'Received ${reminders.length} reminder(s)');

        if (reminders.isEmpty) {
          AppLogger.d('DEBUG_INFO_SCREEN', 'No reminders found');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pending reminders',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: On Android, notifications scheduled with inexactAllowWhileIdle may not appear in pending notifications.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          );
        }

        AppLogger.d('DEBUG_INFO_SCREEN',
            'Building list with ${reminders.length} reminder(s)');

        final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
        final buffer = StringBuffer();
        buffer.writeln('Found ${reminders.length} pending reminder(s):');
        buffer.writeln();

        for (final reminderWithDate in reminders) {
          final reminder = reminderWithDate.reminder;
          final scheduledDate = reminderWithDate.scheduledDate;

          AppLogger.d('DEBUG_INFO_SCREEN',
              'Reminder ID: ${reminder.id}, Title: ${reminder.title}, Payload: ${reminder.payload}, ScheduledDate: $scheduledDate');

          buffer.writeln('ID: ${reminder.id}');
          if (scheduledDate != null) {
            buffer.writeln('Scheduled: ${dateFormat.format(scheduledDate)}');
          }
          if (reminder.title != null && reminder.title!.isNotEmpty) {
            buffer.writeln('Title: ${reminder.title}');
          }
          if (reminder.body != null && reminder.body!.isNotEmpty) {
            buffer.writeln('Body: ${reminder.body}');
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
      WidgetRef ref) async {
    final reminders =
        await ref.read(reminderProvider).getPendingNotifications();
    final prefs = await SharedPreferences.getInstance();
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

    return reminders.map((reminder) {
      DateTime? scheduledDate;

      if (reminder.payload != null && reminder.payload!.isNotEmpty) {
        try {
          scheduledDate = DateTime.parse(reminder.payload!);
          AppLogger.d('DEBUG_INFO_SCREEN',
              'Parsed scheduled date from payload: $scheduledDate');
        } catch (e) {
          AppLogger.d('DEBUG_INFO_SCREEN',
              'Failed to parse payload: ${reminder.payload}, error: $e');
        }
      }

      if (scheduledDate == null &&
          reminder.id >= smartBaseId &&
          reminder.id <= smartBaseId + 15 &&
          savedHour != null &&
          savedMinute != null) {
        final dayOffset = reminder.id - smartBaseId;
        final now = DateTime.now();
        var anchor =
            DateTime(now.year, now.month, now.day, savedHour, savedMinute);
        if (anchor.isBefore(now)) {
          anchor = anchor.add(const Duration(days: 1));
        }
        final daysToAdd = dayOffset == 15 ? 29 : dayOffset;
        scheduledDate = anchor.add(Duration(days: daysToAdd));
        AppLogger.d('DEBUG_INFO_SCREEN',
            'Calculated scheduled date from ID ${reminder.id} (day offset: $dayOffset, days to add: $daysToAdd): $scheduledDate');
      }

      return _ReminderWithDate(
          reminder: reminder, scheduledDate: scheduledDate);
    }).toList();
  }

  void _copyDebugInfo(BuildContext context, WidgetRef ref) async {
    final infoString = await ref.read(deviceAppAndUserInfoProvider.future);
    final paywallManager = ref.read(paywallManagerServiceProvider);
    final donationPlacementId = paywallManager.getDonationPlacementId();
    final fullInfo =
        '$infoString\n\nDonation Placement ID: $donationPlacementId';
    await Clipboard.setData(ClipboardData(text: fullInfo));
    if (context.mounted) {
      showSnackBar(context, AppLocalizations.of(context)!.debugInfoCopied);
    }
  }
}
