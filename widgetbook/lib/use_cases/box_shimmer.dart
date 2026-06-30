import 'package:flutter/material.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: BoxShimmerWidget)
Widget defaultBoxShimmer(BuildContext context) {
  return Center(
    child: BoxShimmerWidget(
      width: context.knobs.double.slider(
        label: 'Width',
        initialValue: 300,
        min: 50,
        max: 400,
      ),
      height: context.knobs.double.slider(
        label: 'Height',
        initialValue: 80,
        min: 20,
        max: 200,
      ),
      borderRadius: context.knobs.double.slider(
        label: 'Border radius',
        initialValue: 14,
        min: 0,
        max: 32,
      ),
    ),
  );
}

@UseCase(name: 'List skeleton', type: BoxShimmerWidget)
Widget listSkeletonShimmer(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BoxShimmerWidget(height: 72, borderRadius: 14),
        ),
      ),
    ),
  );
}
