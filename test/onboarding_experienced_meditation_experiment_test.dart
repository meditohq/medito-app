import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/onboarding/onboarding_experienced_meditation_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Exp = OnboardingExperiencedMeditationExperiment;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('assigns one of the two arms and persists it', () async {
    final prefs = await SharedPreferences.getInstance();
    final assigned = Exp.resolveVariant(prefs);
    expect(assigned, anyOf(Exp.variantControl, Exp.variantOffered));
    expect(
      prefs.getString(
        SharedPreferenceConstants.onboardingExperiencedMeditationVariant,
      ),
      assigned,
    );
  });

  test('is sticky — repeated calls never reassign', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = Exp.resolveVariant(prefs);
    for (var i = 0; i < 50; i++) {
      expect(Exp.resolveVariant(prefs), first);
    }
  });

  test('a stored garbage value is replaced with a valid arm', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.onboardingExperiencedMeditationVariant:
          'not_a_variant',
    });
    final prefs = await SharedPreferences.getInstance();
    final assigned = Exp.resolveVariant(prefs);
    expect(assigned, anyOf(Exp.variantControl, Exp.variantOffered));
  });

  test('assignedVariant never enrols anyone', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(Exp.assignedVariant(prefs), isNull);
    expect(
      prefs.getString(
        SharedPreferenceConstants.onboardingExperiencedMeditationVariant,
      ),
      isNull,
    );
  });

  test('assignedVariant reports the arm once enrolled', () async {
    final prefs = await SharedPreferences.getInstance();
    final assigned = Exp.resolveVariant(prefs);
    expect(Exp.assignedVariant(prefs), assigned);
  });

  test('assignment is roughly balanced across installs', () async {
    var offered = 0;
    const n = 400;
    for (var i = 0; i < n; i++) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      if (Exp.resolveVariant(prefs) == Exp.variantOffered) offered++;
    }
    expect(offered, greaterThan(n * 0.35));
    expect(offered, lessThan(n * 0.65));
  });
}
