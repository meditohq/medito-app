import 'package:flutter/material.dart';
import 'package:medito/widgets/headers/medito_app_bar_large.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'With cover image', type: MeditoAppBarLarge)
Widget appBarLargeWithImage(BuildContext context) {
  final controller = ScrollController();

  return Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        MeditoAppBarLarge(
          scrollController: controller,
          title: context.knobs.string(
            label: 'Title',
            initialValue: 'Mindfulness Basics',
          ),
          coverUrl: context.knobs.string(
            label: 'Cover URL',
            initialValue: 'https://picsum.photos/seed/appbar/800/450',
          ),
          hasLeading: context.knobs.boolean(
            label: 'Has back button',
            initialValue: true,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ListTile(title: Text('Item ${index + 1}')),
            childCount: 20,
          ),
        ),
      ],
    ),
  );
}

@UseCase(name: 'Without cover image', type: MeditoAppBarLarge)
Widget appBarLargeNoImage(BuildContext context) {
  final controller = ScrollController();

  return Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        MeditoAppBarLarge(
          scrollController: controller,
          title: context.knobs.string(
            label: 'Title',
            initialValue: 'Sleep Meditations',
          ),
          hasLeading: context.knobs.boolean(
            label: 'Has back button',
            initialValue: false,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ListTile(title: Text('Item ${index + 1}')),
            childCount: 20,
          ),
        ),
      ],
    ),
  );
}
