import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/reminders/reminder_slots.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the user picked in [ReminderOptionsSheet].
sealed class ReminderChoice {
  const ReminderChoice();
}

class ReminderChoiceSlot extends ReminderChoice {
  const ReminderChoiceSlot(this.slot);
  final ReminderSlot slot;
}

class ReminderChoiceCustom extends ReminderChoice {
  const ReminderChoiceCustom();
}

class ReminderChoiceOff extends ReminderChoice {
  const ReminderChoiceOff();
}

/// Settings card for the daily reminder. Shows the current time (or "Off") and
/// opens [ReminderOptionsSheet] on tap. Replaced the old Smart Reminders
/// switch, which silently picked "same time tomorrow"; this offers the same
/// Morning / Evening / Night / custom choice as the onboarding chips.
class ReminderTile extends ConsumerStatefulWidget {
  const ReminderTile({super.key});

  @override
  ConsumerState<ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends ConsumerState<ReminderTile> {
  /// Permission is permanently denied, so no system prompt can be raised. The
  /// tile says so instead of silently doing nothing.
  bool _notificationsBlocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    // permission_handler has no meaningful status on web (widget previewer).
    if (kIsWeb) return;
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsBlocked = status.isPermanentlyDenied);
    }
  }

  SmartRemindersService _service() => SmartRemindersService(
    prefs: ref.read(sharedPreferencesProvider),
    reminders: ref.read(reminderProvider),
  );

  Future<void> _openSheet() async {
    if (_busy) return;
    final enabled = ref.read(reminderEnabledProvider);
    final current = enabled ? ref.read(reminderTimeProvider) : null;

    final choice = await showModalBottomSheet<ReminderChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (_) => ReminderOptionsSheet(current: current, enabled: enabled),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case ReminderChoiceSlot(:final slot):
        await _enableAt(slot.time, slotId: slot.analyticsId);
      case ReminderChoiceCustom():
        await _pickCustomTime(initial: current);
      case ReminderChoiceOff():
        await _disable();
    }
  }

  Future<void> _pickCustomTime({TimeOfDay? initial}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 7, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null || !mounted) return;
    await _enableAt(picked, slotId: 'custom');
  }

  /// Explain that notifications are switched off for the app, offer the
  /// phone's settings, and if the user comes back having granted permission,
  /// carry on instead of making them pick a time a second time. Returns true
  /// if permission is now granted.
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

  /// Permission first (recover / soft-ask / system prompt), then schedule the
  /// series at [time]. Returns without changing anything if permission is not
  /// granted.
  Future<bool> _ensurePermission() async {
    if (_notificationsBlocked) {
      return _recoverBlockedPermission();
    }

    // Soft-ask before the system prompt: a refusal here can be asked again,
    // a refusal at the system prompt cannot (permanently so on iOS). Skipped
    // when permission is already granted.
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (!mounted) return false;

    final proceed = await showNotificationPermissionPrimer(context);
    if (!proceed || !mounted) return false;

    final accepted = await PermissionHandler.requestNotificationPermission(
      context,
    );
    if (!accepted) {
      // Was a fresh denial permanent? Then the tile should say so.
      await _checkNotificationPermission();
    }
    return accepted;
  }

  Future<void> _enableAt(TimeOfDay time, {required String slotId}) async {
    setState(() => _busy = true);
    try {
      if (!await _ensurePermission() || !mounted) return;

      final anchor = await _service().enableAt(
        time,
        l10n: AppLocalizations.of(context),
      );
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
                AnalyticsEventConstants.paramReminderSlot: slotId,
                AnalyticsEventConstants.paramReminderHour: anchor.hour,
                AnalyticsEventConstants.paramReminderMinute: anchor.minute,
              },
            ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      await ref.read(reminderEnabledProvider.notifier).setEnabled(false);
      await _service().disable();

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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _subtitle(AppLocalizations l10n, bool enabled, TimeOfDay? time) {
    if (!enabled || time == null) {
      return _notificationsBlocked
          ? l10n.notificationsBlockedSubtitle
          : l10n.reminderOff;
    }
    final slot = ReminderSlot.forTime(time);
    final formatted = time.format(context);
    return slot == null ? formatted : '${slot.label(l10n)} · $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(reminderEnabledProvider);
    final time = ref.watch(reminderTimeProvider);

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
            title: l10n.reminderTitle,
            subTitle: _subtitle(l10n, enabled, time),
            hasUnderline: false,
            onTap: _busy ? null : _openSheet,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet body: the three preset slots, a custom-time row, and (when a
/// reminder is scheduled) a turn-off row. Pops with a [ReminderChoice].
class ReminderOptionsSheet extends StatelessWidget {
  const ReminderOptionsSheet({
    super.key,
    required this.current,
    required this.enabled,
  });

  /// Currently scheduled time, null when reminders are off.
  final TimeOfDay? current;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final currentSlot = enabled ? ReminderSlot.forTime(current) : null;
    final isCustom = enabled && current != null && currentSlot == null;

    Widget row({
      required Widget icon,
      required String title,
      String? subTitle,
      required bool selected,
      required ReminderChoice choice,
      bool hasUnderline = true,
    }) {
      return RowItemWidget(
        icon: icon,
        title: title,
        subTitle: subTitle,
        hasUnderline: hasUnderline,
        isTrailingIcon: selected,
        trailingIcon: Icons.check_rounded,
        onTap: () => Navigator.of(context).pop(choice),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.reminderChipsQuestion,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final slot in ReminderSlot.values)
            row(
              icon: MeditoIcon(
                assetName: switch (slot) {
                  ReminderSlot.morning => MeditoIcons.sun,
                  ReminderSlot.evening => MeditoIcons.bell,
                  ReminderSlot.night => MeditoIcons.moon,
                },
                color: onSurface,
              ),
              title: slot.label(l10n),
              subTitle: slot.time.format(context),
              selected: slot == currentSlot,
              choice: ReminderChoiceSlot(slot),
            ),
          row(
            icon: Icon(Icons.schedule_rounded, color: onSurface),
            title: l10n.reminderSlotCustom,
            subTitle: isCustom ? current!.format(context) : null,
            selected: isCustom,
            choice: const ReminderChoiceCustom(),
            hasUnderline: enabled,
          ),
          if (enabled)
            row(
              icon: Icon(Icons.notifications_off_outlined, color: onSurface),
              title: l10n.reminderTurnOff,
              selected: false,
              choice: const ReminderChoiceOff(),
              hasUnderline: false,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
