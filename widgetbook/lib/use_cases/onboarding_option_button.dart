import 'package:flutter/material.dart';
import 'package:medito/widgets/onboarding/onboarding_option_button.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Unselected', type: OnboardingOptionButton)
Widget unselectedOnboardingOptionButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: OnboardingOptionButton(
      label: context.knobs.string(
        label: 'Label',
        initialValue: 'Never tried it',
      ),
      selected: false,
      onTap: () {},
    ),
  );
}

@UseCase(name: 'Selected', type: OnboardingOptionButton)
Widget selectedOnboardingOptionButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: OnboardingOptionButton(
      label: context.knobs.string(
        label: 'Label',
        initialValue: 'A little, here and there',
      ),
      selected: true,
      onTap: () {},
    ),
  );
}
