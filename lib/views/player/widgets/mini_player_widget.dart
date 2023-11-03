import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'artist_title_widget.dart';
import 'player_buttons/play_pause_button_widget.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key, required this.trackModel});
  final TrackModel trackModel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        context.push(RouteConstants.playerPath);
      },
      child: Container(
        height: miniPlayerHeight,
        color: ColorConstants.onyx,
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  trackCoverImage(trackModel.coverUrl),
                  _titleAndSubtitle(),
                ],
              ),
            ),
            _playPauseButton(),
          ],
        ),
      ),
    );
  }

  Padding trackCoverImage(String url) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(7),
            topRight: Radius.circular(2),
            bottomRight: Radius.circular(2),
            bottomLeft: Radius.circular(12)
        ),        child: SizedBox(
          height: 40,
          width: 40,
          child: NetworkImageWidget(
            url: url,
            isCache: true,
          ),
        ),
      ),
    );
  }

  Flexible _titleAndSubtitle() {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtistTitleWidget(
              trackTitle: trackModel.title,
              artistName: trackModel.artist?.name,
              artistUrlPath: trackModel.artist?.path,
              trackTitleFontSize: 16,
              artistNameFontSize: 12,
              artistUrlPathFontSize: 11,
              titleHeight: 20,
            ),
          ],
        ),
      ),
    );
  }

  Padding _playPauseButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PlayPauseButtonWidget(
        iconSize: 40,
      ),
    );
  }
}
