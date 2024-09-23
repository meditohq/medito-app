import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/meditation/track_provider.dart';
import 'bottom_action_bar.dart';

class TrackViewBottomBar extends ConsumerWidget {
  final String trackId;
  final VoidCallback onBackPressed;

  const TrackViewBottomBar({
    Key? key,
    required this.trackId,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteStatus = ref.watch(favoriteStatusProvider(trackId: trackId));

    const dailyMeditationId = 'BmTFAyYt8jVMievZ'; // from back end :(
    var isDailyMeditation = trackId == dailyMeditationId;
    var colour =
        favoriteStatus ? ColorConstants.lightPurple : ColorConstants.white;

    return BottomActionBar(
      leftItem: BottomActionBarItem(
        child: const Icon(Icons.arrow_back),
        onTap: onBackPressed,
      ),
      rightItem: isDailyMeditation
          ? null
          : BottomActionBarItem(
              child: Icon(
                Icons.star,
                color: colour,
              ),
              onTap: () {
                ref
                    .read(favoriteStatusProvider(trackId: trackId).notifier)
                    .toggle();
              },
            ),
    );
  }
}
