import 'package:flutter/material.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: MeditoAppBarSmall)
Widget defaultAppBarSmall(BuildContext context) {
  return Scaffold(
    appBar: MeditoAppBarSmall(
      title: context.knobs.string(label: 'Title', initialValue: 'Meditations'),
      hasBackButton: context.knobs.boolean(
        label: 'Back button',
        initialValue: true,
      ),
      hasCloseButton: context.knobs.boolean(
        label: 'Close button',
        initialValue: false,
      ),
    ),
    body: const SizedBox.shrink(),
  );
}
