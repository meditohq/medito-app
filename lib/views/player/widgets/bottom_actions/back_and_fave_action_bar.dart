import 'package:hugeicons/hugeicons.dart';
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
    var icon = favoriteStatus
        ? HugeIcons.solidRoundedStar
        : HugeIcons.strokeRoundedStar;

    return BottomActionBar(
      leftItem: BottomActionBarItem(
        child: HugeIcon(icon: HugeIcons.solidSharpArrowLeft02, color: Colors.white,),
        onTap: onBackPressed,
      ),
      rightItem: isDailyMeditation
          ? null
          : BottomActionBarItem(
              child: HugeIcon(
                icon: icon,
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
