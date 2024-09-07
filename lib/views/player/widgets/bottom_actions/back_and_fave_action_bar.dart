import 'package:Medito/constants/colors/color_constants.dart';
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

    final dailyMeditationId = 'BmTFAyYt8jVMievZ'; // from back end :(
    var isDailyMeditation = trackId == dailyMeditationId;
    var colour = favoriteStatus
        ? ColorConstants.lightPurple
        : ColorConstants.walterWhite;

    return BottomActionBar(
      actions: [
        IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: onBackPressed,
        ),
        isDailyMeditation
            ? Container()
            : IconButton(
                icon: Icon(
                  Icons.star,
                  color: colour,
                ),
                onPressed: () {
                  ref
                      .read(favoriteStatusProvider(trackId: trackId).notifier)
                      .toggle();
                },
              ),
      ],
    );
  }
}
