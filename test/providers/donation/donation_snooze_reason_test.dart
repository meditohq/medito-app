import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/donation_snooze_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> container(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  final future = DateTime.now().add(const Duration(days: 10));

  test('"Hide for now" snooze with no donation on record is hidden', () async {
    final c = await container({
      SharedPreferenceConstants.donationAskSnoozedUntilMs:
          future.millisecondsSinceEpoch,
    });
    final state = c.read(donationSnoozeProvider);
    expect(state.isSnoozed, isTrue);
    expect(state.isDonor, isFalse);
    expect(state.snoozeReason, 'hidden');
  });

  test('a completed donation marks the install as donor', () async {
    final c = await container({});
    await c
        .read(donationSnoozeProvider.notifier)
        .recordDonationSuccess('monthly');
    final state = c.read(donationSnoozeProvider);
    expect(state.isSnoozed, isTrue);
    expect(state.isDonor, isTrue);
    expect(state.snoozeReason, 'donor');
  });

  test('a past donor who later hides the ask still counts as donor', () async {
    final c = await container({
      SharedPreferenceConstants.lastSuccessfulDonationAtMs: DateTime.now()
          .subtract(const Duration(days: 400))
          .millisecondsSinceEpoch,
    });
    expect(c.read(donationSnoozeProvider).isSnoozed, isFalse);
    await c.read(donationSnoozeProvider.notifier).snoozeForDays(30);
    final state = c.read(donationSnoozeProvider);
    expect(state.isSnoozed, isTrue);
    expect(state.snoozeReason, 'donor');
  });
}
