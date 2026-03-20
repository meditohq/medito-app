import 'package:flutter/material.dart';
import 'package:medito/widgets/onboarding/progress_indicator_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: OnboardingProgressIndicator)
Widget defaultProgressIndicator(BuildContext context) {
  final total = context.knobs.int.slider(
    label: 'Total steps',
    initialValue: 5,
    min: 2,
    max: 10,
  );
  final current = context.knobs.int.slider(
    label: 'Current index',
    initialValue: 2,
    min: 0,
    max: 9,
  );

  return Center(
    child: OnboardingProgressIndicator(
      currentIndex: current.clamp(0, total - 1),
      totalSteps: total,
    ),
  );
}
