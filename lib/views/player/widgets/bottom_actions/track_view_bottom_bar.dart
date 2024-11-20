import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import '../../../../providers/meditation/track_provider.dart';
import '../../../../widgets/add_to_siri_button.dart';
import 'bottom_action_bar.dart';

class TrackViewBottomBar extends ConsumerWidget {
  final String trackId;
  final String trackName;
  final VoidCallback onBackPressed;

  const TrackViewBottomBar({
    super.key,
    required this.trackId,
    required this.trackName,
    required this.onBackPressed,
  });

  void _shareTrack() {
    var deepLink = 'medito.app://tracks/$trackId';
    Share.share(deepLink);
  }

  Widget _buildPlatformSpecificButton() {
    var shareIcon = Platform.isIOS 
        ? HugeIcons.strokeRoundedShare05
        : HugeIcons.strokeRoundedShare08;

    if (Platform.isIOS) {
      return PopupMenuButton<String>(
        icon: HugeIcon(
          icon: shareIcon,
          color: ColorConstants.white,
        ),
        color: ColorConstants.onyx,
        itemBuilder: (context) => [
          PopupMenuItem(
            child: AddToSiriButton(
              title: 'Open $trackName',
              id: trackId,
              url: 'org.meditofoundation://tracks/$trackId',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.bulkRoundedSiri,
                    color: ColorConstants.white,
                    size: 20,
                  ),
                  Text(
                    'Add to Siri',
                    style: TextStyle(color: ColorConstants.white),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuItem(
            onTap: _shareTrack,
            child: Row(
              children: [
                HugeIcon(
                  icon: shareIcon,
                  color: ColorConstants.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Share Track',
                  style: TextStyle(color: ColorConstants.white),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return HugeIcon(
      icon: shareIcon,
      color: ColorConstants.white,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteStatus = ref.watch(favoriteStatusProvider(trackId: trackId));

    const dailyMeditationId = 'BmTFAyYt8jVMievZ'; // from back end :(
    var isDailyMeditation = trackId == dailyMeditationId;
    var colour = favoriteStatus ? ColorConstants.lightPurple : ColorConstants.white;
    var icon = favoriteStatus ? HugeIcons.solidRoundedStar : HugeIcons.strokeRoundedStar;

    return BottomActionBar(
      layout: BottomActionBarLayout.compactRight,
      leftItem: BottomActionBarItem(
        child: HugeIcon(
          icon: HugeIcons.solidSharpArrowLeft02,
          color: Colors.white,
        ),
        onTap: onBackPressed,
      ),
      rightCenterItem: BottomActionBarItem(
        child: _buildPlatformSpecificButton(),
        onTap: Platform.isIOS ? null : _shareTrack,
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
