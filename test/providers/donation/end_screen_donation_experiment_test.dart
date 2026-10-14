import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/end_screen_donation_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh installs get the inline variant and persist it', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.resolveVariant(prefs), 'B');
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      'B',
    );
  });

  test('former control installs move to inline', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.endScreenDonationAskVariant: 'A',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.resolveVariant(prefs), 'B');
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      'B',
    );
  });

  test('a corrupt stored value is replaced with inline', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.endScreenDonationAskVariant: 'garbage',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.resolveVariant(prefs), 'B');
  });

  test('peek is inline for everyone and never assigns', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.isInlineVariant(prefs), isTrue);
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      isNull,
    );
  });

  test('payment metadata carries the arm and never assigns', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.paymentMetadata(prefs), isEmpty);
    expect(
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant),
      isNull,
    );

    EndScreenDonationExperiment.resolveVariant(prefs);
    expect(EndScreenDonationExperiment.paymentMetadata(prefs), {
      'end_screen_inline_pay': 'B',
    });
  });

  test('payment metadata ignores a corrupt stored value', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.endScreenDonationAskVariant: 'garbage',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(EndScreenDonationExperiment.paymentMetadata(prefs), isEmpty);
  });
}
