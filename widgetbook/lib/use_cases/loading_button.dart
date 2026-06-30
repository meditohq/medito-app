import 'package:flutter/material.dart';
import 'package:medito/widgets/buttons/loading_button_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: LoadingButtonWidget)
Widget defaultLoadingButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: LoadingButtonWidget(
      btnText: context.knobs.string(
        label: 'Button text',
        initialValue: 'Get Started',
      ),
      isLoading: context.knobs.boolean(label: 'Loading', initialValue: false),
      onPressed: () {},
    ),
  );
}

@UseCase(name: 'Loading state', type: LoadingButtonWidget)
Widget loadingStateButton(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(24),
    child: LoadingButtonWidget(btnText: 'Saving...', isLoading: true),
  );
}
