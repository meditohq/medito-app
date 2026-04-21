import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

class SmartReminderTile extends ConsumerWidget {
  const SmartReminderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(reminderEnabledProvider);

    Future<void> handleToggle(bool value) async {
      if (value) {
        var accepted =
            await PermissionHandler.requestAlarmPermission(context);
        if (!accepted) return;

        final prefs = ref.read(sharedPreferencesProvider);
        final service = SmartRemindersService(
          prefs: prefs,
          reminders: ref.read(reminderProvider),
        );

        final time = await service.enable();
        await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
        await ref.read(reminderTimeProvider.notifier).setTime(time);

        unawaited(
          ref.read(analyticsServiceProvider).logEvent(
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
      }
    }

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
            subTitle: null,
            hasUnderline: false,
            isSwitch: true,
            switchValue: isEnabled,
            onTap: () => handleToggle(!isEnabled),
            onSwitchChanged: handleToggle,
          ),
        ),
      ),
    );
  }
}

