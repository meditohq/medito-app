import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/end_screen_donation_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('assigns A or B once and persists it', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = EndScreenDonationExperiment.resolveVariant(prefs);
    expect(first, isIn(['A', 'B']));
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      first,
    );
    for (var i = 0; i < 20; i++) {
      expect(EndScreenDonationExperiment.resolveVariant(prefs), first);
    }
  });

  test('honours a previously stored variant', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.endScreenDonationAskVariant: 'B',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.resolveVariant(prefs), 'B');
    expect(EndScreenDonationExperiment.isInlineVariant(prefs), isTrue);
  });

  test('re-assigns a corrupt stored value instead of trusting it', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.endScreenDonationAskVariant: 'garbage',
    });
    final prefs = await SharedPreferences.getInstance();
    final resolved = EndScreenDonationExperiment.resolveVariant(prefs);
    expect(resolved, isIn(['A', 'B']));
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      resolved,
    );
  });

  test('peek never assigns', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.isInlineVariant(prefs), isFalse);
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      isNull,
    );
  });

  test('is roughly 50/50 over many fresh installs', () async {
    var inline = 0;
    const n = 400;
    for (var i = 0; i < n; i++) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      if (EndScreenDonationExperiment.resolveVariant(prefs) == 'B') inline++;
    }
    // 400 fair coin flips land in [140, 260] with overwhelming probability.
    expect(inline, inInclusiveRange(140, 260));
  });
}
