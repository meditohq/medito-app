import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../constants/colors/color_constants.dart';
import '../../../../../providers/meditation/track_provider.dart';

class MarkFavouriteWidget extends ConsumerWidget {
  final String trackId;

  const MarkFavouriteWidget({
    Key? key,
    required this.trackId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(favoriteStatusProvider(trackId: trackId));

    return IconButton(
      onPressed: () =>
          ref.read(favoriteStatusProvider(trackId: trackId).notifier).toggle(),
      icon: Icon(
        Icons.star,
        color:
            isLiked ? ColorConstants.lightPurple : ColorConstants.walterWhite,
      ),
    );
  }
}
