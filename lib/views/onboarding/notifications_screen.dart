// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _notificationsGranted = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsGranted = status.isGranted);
    }
  }

  void _handleNotificationsPermission() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    final handler = ref.read(firebaseMessagingProvider);
    final status = await Permission.notification.request();

    if (!mounted) return;

    if (status.isGranted) {
      await handler.initialize(context, ref);
      if (mounted) {
        setState(() {
          _notificationsGranted = true;
          _isProcessing = false;
        });
      }
    } else {
      // Permission denied - log analytics event for onboarding context
      if (status.isDenied || status.isPermanentlyDenied) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService
              .eventOnboardingNotificationsPermissionDenied,
          parameters: {
            'permission_status':
                status.isPermanentlyDenied ? 'permanently_denied' : 'denied',
          },
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleSetReminder() async {
    final accepted = await PermissionHandler.requestAlarmPermission(context);
    if (!accepted || !mounted) return;

    final reminders = ref.read(reminderProvider);
    final prefs = await SharedPreferences.getInstance();
    final initialTime = ref.read(reminderTimeProvider) ?? TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: AppLocalizations.of(context)!.pickTimeHelpText,
    );

    if (pickedTime != null && mounted) {
      await reminders.scheduleDailyNotification(pickedTime);
      await prefs.setInt(SharedPreferenceConstants.savedHours, pickedTime.hour);
      await prefs.setInt(
          SharedPreferenceConstants.savedMinutes, pickedTime.minute);
      ref.read(reminderTimeProvider.notifier).state = pickedTime;
      _navigateNext();
    }
  }

  void _navigateNext() => widget.onNext?.call();

  @override
  Widget build(BuildContext context) {
    final reminderTime = ref.watch(reminderTimeProvider);

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.enableNotificationsTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.enableNotificationsBody,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  if (reminderTime != null)
                    _buildTimeButton(reminderTime)
                  else if (_notificationsGranted)
                    _buildActionButton(
                      text: AppLocalizations.of(context)!.setReminder,
                      onPressed: _handleSetReminder,
                    )
                  else
                    _buildActionButton(
                      text:
                          AppLocalizations.of(context)!.enableNotificationsCta,
                      onPressed:
                          _isProcessing ? null : _handleNotificationsPermission,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _navigateNext,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.skipForNow,
                        style: const TextStyle(
                          color: ColorConstants.lightPurple,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton(TimeOfDay reminderTime) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _navigateNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.lightPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          '${AppLocalizations.of(context)!.setFor} ${reminderTime.format(context)}',
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.lightPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
