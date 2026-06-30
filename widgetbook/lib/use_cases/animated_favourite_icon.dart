import 'package:flutter/material.dart';
import 'package:medito/views/player/widgets/bottom_actions/animated_favourite_icon.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: AnimatedFavouriteIcon)
Widget defaultAnimatedFavouriteIcon(BuildContext context) {
  return Center(
    child: AnimatedFavouriteIcon(
      key: ValueKey(
        context.knobs.boolean(label: 'Is favourite', initialValue: false),
      ),
      isFavorite: context.knobs.boolean(
        label: 'Is favourite',
        initialValue: false,
      ),
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}
