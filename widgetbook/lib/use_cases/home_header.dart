import 'package:flutter/material.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: HomeHeaderWidget)
Widget defaultHomeHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: HomeHeaderWidget(
      greeting: context.knobs.string(
        label: 'Greeting',
        initialValue: 'Good morning, Mike',
      ),
    ),
  );
}
