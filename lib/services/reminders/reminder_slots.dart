import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';

/// The time-of-day presets offered for the daily reminder. Same three slots as
/// the onboarding chips (shipped to everyone after the reminder time-chips A/B
/// concluded 2026-08-25); Settings offers them again in a bottom sheet so the
/// two surfaces agree.
enum ReminderSlot {
  morning('morning', TimeOfDay(hour: 7, minute: 0)),
  evening('evening', TimeOfDay(hour: 20, minute: 0)),
  night('night', TimeOfDay(hour: 22, minute: 0));

  const ReminderSlot(this.analyticsId, this.time);

  /// Value sent as `reminder_slot` (AnalyticsEventConstants.paramReminderSlot).
  final String analyticsId;
  final TimeOfDay time;

  String label(AppLocalizations l10n) => switch (this) {
    ReminderSlot.morning => l10n.reminderSlotMorning,
    ReminderSlot.evening => l10n.reminderSlotEvening,
    ReminderSlot.night => l10n.reminderSlotNight,
  };

  /// The preset matching [time] exactly, or null for a custom time.
  static ReminderSlot? forTime(TimeOfDay? time) {
    if (time == null) return null;
    for (final slot in values) {
      if (slot.time == time) return slot;
    }
    return null;
  }
}
