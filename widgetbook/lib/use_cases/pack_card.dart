import 'package:flutter/material.dart';
import 'package:medito/widgets/pack_card_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'With cover image', type: PackCardWidget)
Widget packCardWithImage(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: PackCardWidget(
      title: context.knobs.string(
        label: 'Title',
        initialValue: 'Mindfulness Basics',
      ),
      subTitle: context.knobs.string(
        label: 'Subtitle',
        initialValue: '8 sessions · Beginner',
      ),
      coverUrlPath: context.knobs.string(
        label: 'Cover URL',
        initialValue: 'https://picsum.photos/seed/pack/800/450',
      ),
      onTap: () {},
    ),
  );
}

@UseCase(name: 'Without cover image', type: PackCardWidget)
Widget packCardNoImage(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: PackCardWidget(
      title: 'Mindfulness Basics',
      subTitle: '8 sessions · Beginner',
      onTap: () {},
    ),
  );
}
