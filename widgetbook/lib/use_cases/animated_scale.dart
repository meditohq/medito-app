import 'package:flutter/material.dart';
import 'package:medito/views/home/widgets/animated_scale_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: AnimatedScaleWidget)
Widget defaultAnimatedScale(BuildContext context) {
  final scale = context.knobs.double.slider(
    label: 'Press scale',
    initialValue: 0.92,
    min: 0.7,
    max: 0.99,
  );

  return Center(
    child: AnimatedScaleWidget(
      scale: scale,
      child: Container(
        width: 200,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          'Press me',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
