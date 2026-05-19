import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../shared_preference/shared_preference_provider.dart';

part 'donation_snooze_provider.g.dart';

class DonationSnoozeState {
  final bool isSnoozed;
  final String? lastDonationFrequency;
  final DateTime? lastDonationAt;
  final DateTime? snoozedUntil;

  DonationSnoozeState({
    required this.isSnoozed,
    this.lastDonationFrequency,
    this.lastDonationAt,
    this.snoozedUntil,
  });
}

@riverpod
class DonationSnooze extends _$DonationSnooze {
  @override
  DonationSnoozeState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final snoozedUntilMs = prefs.getInt(
      SharedPreferenceConstants.donationAskSnoozedUntilMs,
    );
    final lastDonationAtMs = prefs.getInt(
      SharedPreferenceConstants.lastSuccessfulDonationAtMs,
    );
    final lastDonationFrequency = prefs.getString(
      SharedPreferenceConstants.lastSuccessfulDonationFrequency,
    );

    final now = DateTime.now();
    final isSnoozed =
        snoozedUntilMs != null && now.millisecondsSinceEpoch < snoozedUntilMs;

    return DonationSnoozeState(
      isSnoozed: isSnoozed,
      lastDonationFrequency: lastDonationFrequency,
      lastDonationAt: lastDonationAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastDonationAtMs)
          : null,
      snoozedUntil: snoozedUntilMs != null
          ? DateTime.fromMillisecondsSinceEpoch(snoozedUntilMs)
          : null,
    );
  }

  Future<void> snoozeForDays(int days) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final snoozedUntil = now.add(Duration(days: days));

    await prefs.setInt(
      SharedPreferenceConstants.donationAskSnoozedUntilMs,
      snoozedUntil.millisecondsSinceEpoch,
    );

    ref.invalidateSelf();
  }

  Future<void> recordDonationSuccess(String frequency) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();

    final snoozeDays = frequency == 'onetime'
        ? 60
        : frequency == 'yearly'
            ? 365
            : 30; // monthly
    final snoozedUntil = now.add(Duration(days: snoozeDays));

    await prefs.setInt(
      SharedPreferenceConstants.lastSuccessfulDonationAtMs,
      now.millisecondsSinceEpoch,
    );
    await prefs.setString(
      SharedPreferenceConstants.lastSuccessfulDonationFrequency,
      frequency,
    );
    await prefs.setInt(
      SharedPreferenceConstants.donationAskSnoozedUntilMs,
      snoozedUntil.millisecondsSinceEpoch,
    );

    ref.invalidateSelf();
  }
}
