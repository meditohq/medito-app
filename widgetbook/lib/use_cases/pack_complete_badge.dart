import 'package:flutter/material.dart';
import 'package:medito/views/pack/widgets/pack_complete_badge.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: PackCompleteBadge)
Widget packCompleteBadge(BuildContext context) {
  return Center(
    child: PackCompleteBadge(
      size: context.knobs.double.slider(
        label: 'Size',
        initialValue: 24,
        min: 16,
        max: 48,
      ),
    ),
  );
}
