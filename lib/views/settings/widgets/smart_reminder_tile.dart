import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

class SmartReminderTile extends ConsumerStatefulWidget {
  const SmartReminderTile({super.key});

  @override
  ConsumerState<SmartReminderTile> createState() => _SmartReminderTileState();
}

class _SmartReminderTileState extends ConsumerState<SmartReminderTile> {
  /// Permission is permanently denied, so flipping the switch can raise no
  /// system prompt. The tile says so instead of snapping silently back off.
  bool _notificationsBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsBlocked = status.isPermanentlyDenied);
    }
  }

  /// Explain that notifications are switched off for the app, offer the
  /// phone's settings, and if the user comes back having granted permission,
  /// carry on and enable the reminder instead of making them flip the switch
  /// a second time. Returns true if permission is now granted.
  Future<bool> _recoverBlockedPermission() async {
    final analytics = ref.read(analyticsServiceProvider);
    const params = {
      AnalyticsEventConstants.paramSource:
          AnalyticsEventConstants.sourceSettings,
    };

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationSettingsPromptShown,
        parameters: params,
      ),
    );

    final go = await showNotificationsBlockedDialog(context);
    if (!go) return false;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationSettingsOpened,
        parameters: params,
      ),
    );

    final granted = await openSettingsAndAwaitPermission();
    if (!mounted) return false;

    setState(() => _notificationsBlocked = !granted);
    if (!granted) return false;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationPermissionRecovered,
        parameters: params,
      ),
    );
    return true;
  }

  Future<void> _handleToggle(bool value) async {
    if (value) {
      if (_notificationsBlocked) {
        final recovered = await _recoverBlockedPermission();
        if (!recovered || !mounted) return;
      } else {
        // Soft-ask before the system prompt: a refusal here can be asked
        // again, a refusal at the system prompt cannot (permanently so on
        // iOS). Skipped when permission is already granted.
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          if (!mounted) return;
          final proceed = await showNotificationPermissionPrimer(context);
          if (!proceed || !mounted) return;
        }

        if (!mounted) return;
        final accepted = await PermissionHandler.requestNotificationPermission(
          context,
        );
        if (!accepted) {
          // Was a fresh denial permanent? If so the tile should now say the
          // switch cannot do anything until settings change.
          await _checkNotificationPermission();
          return;
        }
      }

      final prefs = ref.read(sharedPreferencesProvider);
      final service = SmartRemindersService(
        prefs: prefs,
        reminders: ref.read(reminderProvider),
      );

      final time = await service.enable();
      await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
      await ref.read(reminderTimeProvider.notifier).setTime(time);

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.notificationsEnabled,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceSettings,
              },
            ),
      );
    } else {
      final prefs = ref.read(sharedPreferencesProvider);
      final service = SmartRemindersService(
        prefs: prefs,
        reminders: ref.read(reminderProvider),
      );
      await ref.read(reminderEnabledProvider.notifier).setEnabled(false);
      await service.disable();

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.notificationsDisabled,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceSettings,
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(reminderEnabledProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: HomeGradientBorder(
        backgroundColor: Theme.of(context).cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: RowItemWidget(
            icon: MeditoIcon(
              assetName: MeditoIcons.bell,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: AppLocalizations.of(context)!.smartReminders,
            subTitle: _notificationsBlocked && !isEnabled
                ? AppLocalizations.of(context)!.notificationsBlockedSubtitle
                : null,
            hasUnderline: false,
            isSwitch: true,
            switchValue: isEnabled,
            onTap: () => _handleToggle(!isEnabled),
            onSwitchChanged: _handleToggle,
          ),
        ),
      ),
    );
  }
}
