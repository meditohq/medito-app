import 'package:flutter/material.dart';
import 'package:medito/views/tags/widgets/tag_chip.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: TagChip)
Widget defaultTagChip(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TagChip(
        label: context.knobs.string(label: 'Label', initialValue: 'Sleep'),
        onTap: () {},
      ),
    ),
  );
}

@UseCase(name: 'Wrapping row', type: TagChip)
Widget rowOfTagChips(BuildContext context) {
  const labels = ['Sleep', 'Stress', 'Breathing', 'Body scan', 'Focus'];
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels) TagChip(label: label, onTap: () {}),
      ],
    ),
  );
}
