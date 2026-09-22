import 'package:flutter_test/flutter_test.dart';
import 'package:medito/providers/onboarding/onboarding_donation_timing_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Exp = OnboardingDonationTimingExperiment;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('assignment survives a fresh preferences instance', () async {
    final prefs = await SharedPreferences.getInstance();
    final variant = Exp.resolveVariant(prefs);
    expect(variant, anyOf('A', 'B'));
    await prefs.reload();
    expect(Exp.resolveVariant(await SharedPreferences.getInstance()), variant);
  });

  test('payment attribution never enrolls existing users', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(Exp.paymentMetadata(prefs), isEmpty);
    expect(prefs.containsKey(Exp.preferenceKey), isFalse);
  });

  test('payment attribution preserves other experiment metadata', () async {
    SharedPreferences.setMockInitialValues({Exp.preferenceKey: 'B'});
    final prefs = await SharedPreferences.getInstance();
    final metadata = {
      'experiment_id': 'end_screen_inline_pay',
      'experiment_variant': 'A',
      ...Exp.paymentMetadata(prefs),
    };
    expect(metadata['experiment_variant'], 'A');
    expect(metadata[Exp.userProperty], 'B');
    expect(Exp.resolveVariant(prefs), 'B');
  });

  test('invalid saved assignment is repaired', () async {
    SharedPreferences.setMockInitialValues({Exp.preferenceKey: 'invalid'});
    final prefs = await SharedPreferences.getInstance();
    expect(Exp.assignedVariant(prefs), isNull);
    expect(Exp.resolveVariant(prefs), anyOf('A', 'B'));
  });

  for (final battery in [false, true]) {
    for (final tracking in [false, true]) {
      test('only the ask moves (battery=$battery, tracking=$tracking)', () {
        final a = Exp.steps(
          variant: 'A',
          showBattery: battery,
          showTracking: tracking,
        );
        final b = Exp.steps(
          variant: 'B',
          showBattery: battery,
          showTracking: tracking,
        );
        expect(a[1], OnboardingStep.donation);
        expect(a.last, OnboardingStep.result);
        expect(b.last, OnboardingStep.donation);
        expect(b[b.length - 2], OnboardingStep.result);
        expect(
          a.where((x) => x != OnboardingStep.donation).toList(),
          b.where((x) => x != OnboardingStep.donation).toList(),
        );
        expect(a.toSet().length, a.length);
        expect(b.toSet().length, b.length);
        expect(b.contains(OnboardingStep.battery), battery);
        expect(b.contains(OnboardingStep.tracking), tracking);
      });
    }
  }
}
