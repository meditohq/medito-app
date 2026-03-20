import 'package:flutter/material.dart';
import 'package:medito/widgets/drop_down_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: DropdownWidget)
Widget defaultDropdown(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownWidget<String>(
        isLandscape: false,
        iconData: Icons.timer_outlined,
        value: '10 min',
        items: const [
          DropdownMenuItem(value: '5 min', child: Text('5 min')),
          DropdownMenuItem(value: '10 min', child: Text('10 min')),
          DropdownMenuItem(value: '15 min', child: Text('15 min')),
          DropdownMenuItem(value: '20 min', child: Text('20 min')),
        ],
        onChanged: (_) {},
      ),
    ),
  );
}

@UseCase(name: 'Disabled (single item)', type: DropdownWidget)
Widget disabledDropdown(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownWidget<String>(
        isLandscape: false,
        disabledLabelText: context.knobs.string(
          label: 'Disabled label',
          initialValue: 'No options available',
        ),
        items: null,
        onChanged: null,
      ),
    ),
  );
}

@UseCase(name: 'Landscape', type: DropdownWidget)
Widget landscapeDropdown(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownWidget<String>(
        isLandscape: true,
        iconData: Icons.person_outline,
        value: 'Any guide',
        items: const [
          DropdownMenuItem(value: 'Any guide', child: Text('Any guide')),
          DropdownMenuItem(value: 'Guide A', child: Text('Guide A')),
          DropdownMenuItem(value: 'Guide B', child: Text('Guide B')),
        ],
        onChanged: (_) {},
      ),
    ),
  );
}
