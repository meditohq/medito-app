import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart';

import '../../../../providers/meditation/track_provider.dart';
import '../../../../widgets/add_to_siri_util.dart';
import 'bottom_action_bar.dart';
import 'package:medito/constants/strings/string_constants.dart';

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
    final deepLink = 'https://medito.app/tracks/$trackId';
    final shareText = StringConstants.shareTrackText
        .replaceAll('{trackName}', trackName)
        .replaceAll('{link}', deepLink);
    Share.share(shareText);
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      showDragHandle: true,
      context: context,
      backgroundColor: ColorConstants.onyx,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.solidRoundedSiri,
                color: ColorConstants.white,
                size: 20,
              ),
              title: const Text(
                StringConstants.addToSiri,
                style: TextStyle(color: ColorConstants.white),
              ),
              onTap: () {
                addToSiri(
                  title: '${StringConstants.open} $trackName',
                  id: trackId,
                  url: 'org.meditofoundation://tracks/$trackId',
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: HugeIcon(
                icon: Platform.isIOS 
                  ? HugeIcons.strokeRoundedShare05
                  : HugeIcons.strokeRoundedShare08,
                color: ColorConstants.white,
                size: 20,
              ),
              title: const Text(
                StringConstants.shareTrack,
                style: TextStyle(color: ColorConstants.white),
              ),
              onTap: () {
                _shareTrack();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformSpecificButton() {
    var shareIcon = Platform.isIOS 
        ? HugeIcons.strokeRoundedShare05
        : HugeIcons.strokeRoundedShare08;

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
        onTap: Platform.isIOS ? () => _showBottomSheet(context) : _shareTrack,
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
