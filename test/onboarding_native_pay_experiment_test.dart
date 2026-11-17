import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/onboarding/onboarding_native_pay_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Exp = OnboardingNativePayExperiment;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('assigns once and stays sticky', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(Exp.assignedVariant(prefs), isNull);
    expect(Exp.paymentMetadata(prefs), isEmpty);

    final first = Exp.resolveVariant(prefs, random: Random(1));
    for (var i = 0; i < 20; i++) {
      expect(Exp.resolveVariant(prefs, random: Random(i)), first);
    }
    expect(Exp.paymentMetadata(prefs), {'onboarding_native_pay': first});
  });

  test('splits roughly 50/50', () async {
    final random = Random(42);
    var native = 0;
    for (var i = 0; i < 2000; i++) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      if (Exp.resolveVariant(prefs, random: random) == Exp.variantNative) {
        native++;
      }
    }
    expect(native, inInclusiveRange(900, 1100));
  });

  test('ignores and replaces junk stored values', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.onboardingNativePayVariant: 'native',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(Exp.assignedVariant(prefs), isNull);
    expect(Exp.paymentMetadata(prefs), isEmpty);
    expect([
      Exp.variantWebview,
      Exp.variantNative,
    ], contains(Exp.resolveVariant(prefs)));
  });
}
