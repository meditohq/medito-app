import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'artist_title_widget.dart';
import 'player_buttons/play_pause_button_widget.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key, required this.meditationModel});
  final MeditationModel meditationModel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var systemGestureInsets = MediaQuery.of(context).systemGestureInsets;
    print(systemGestureInsets.bottom);
    var bottom = 32.0;
    bottom = systemGestureInsets.bottom > 32 ? systemGestureInsets.bottom : 16;

    return InkWell(
      onTap: () {
        ref.read(pageviewNotifierProvider).gotoNextPage();
      },
      child: Container(
        height: bottom + 64,
        color: ColorConstants.onyx,
        padding: EdgeInsets.only(bottom: bottom),
        child: Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  meditationCoverImage(meditationModel.coverUrl),
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

  Padding meditationCoverImage(String url) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
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
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtistTitleWidget(
              meditationTitle: meditationModel.title,
              artistName: meditationModel.artist?.name,
              artistUrlPath: meditationModel.artist?.path,
              meditationTitleFontSize: 16,
              artistNameFontSize: 12,
              artistUrlPathFontSize: 11,
              titleHeight: 22,
            ),
          ],
        ),
      ),
    );
  }

  Padding _playPauseButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: PlayPauseButtonWidget(
        iconSize: 40,
      ),
    );
  }
}
