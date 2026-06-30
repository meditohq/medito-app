import 'package:flutter/material.dart';
import 'package:medito/widgets/track_card_widget.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'With cover image', type: TrackCardWidget)
Widget trackCardWithImage(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: TrackCardWidget(
      title: context.knobs.string(
        label: 'Title',
        initialValue: 'Breathing for Anxiety',
      ),
      subTitle: context.knobs.string(
        label: 'Subtitle',
        initialValue: '10 min · Guided meditation',
      ),
      coverUrlPath: context.knobs.string(
        label: 'Cover URL',
        initialValue: 'https://picsum.photos/seed/medito/200/200',
      ),
      onTap: () {},
    ),
  );
}

@UseCase(name: 'Without cover image', type: TrackCardWidget)
Widget trackCardNoImage(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: TrackCardWidget(
      title: 'Breathing for Anxiety',
      subTitle: '10 min · Guided meditation',
      onTap: () {},
    ),
  );
}
