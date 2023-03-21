import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/player/audio_play_pause_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key, required this.sessionModel});
  final SessionModel sessionModel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      color: ColorConstants.greyIsTheNewGrey,
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                sessionCoverImage(sessionModel.coverUrl),
                _titleAndSubtitle(context),
              ],
            ),
          ),
          _playPauseButton(ref)
        ],
      ),
    );
  }

  Padding sessionCoverImage(String url) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: SizedBox(
        height: 40,
        width: 40,
        child: NetworkImageComponent(url: url),
      ),
    );
  }

  Flexible _titleAndSubtitle(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context),
            _subtitle(context),
          ],
        ),
      ),
    );
  }

  Text _title(BuildContext context) {
    return Text(
      sessionModel.title,
      textAlign: TextAlign.left,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
          fontFamily: ClashDisplay,
          color: ColorConstants.walterWhite,
          fontSize: 16,
          letterSpacing: 1),
    );
  }

  SizedBox _subtitle(BuildContext context) {
    if (sessionModel.artist == null) {
      return SizedBox();
    }
    return SizedBox(
      height: 15,
      child: MarkdownComponent(
        body:
            '${sessionModel.artist?.name ?? ''} ${sessionModel.artist?.path ?? ''}',
        textAlign: WrapAlignment.start,
        p: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: DmMono,
            letterSpacing: 1,
            fontSize: 12,
            color: ColorConstants.walterWhite.withOpacity(0.9),
            overflow: TextOverflow.ellipsis),
        a: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: DmMono,
            color: ColorConstants.walterWhite.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Padding _playPauseButton(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: InkWell(
        onTap: () {
          var _state = ref.watch(audioPlayPauseStateProvider.notifier).state;
          ref.read(audioPlayPauseStateProvider.notifier).state =
              _state == PLAY_PAUSE_AUDIO.PAUSE
                  ? PLAY_PAUSE_AUDIO.PLAY
                  : PLAY_PAUSE_AUDIO.PAUSE;
        },
        child: AnimatedCrossFade(
          firstChild: Icon(
            Icons.play_circle_fill,
            size: 40,
            color: ColorConstants.walterWhite,
          ),
          secondChild: Icon(
            Icons.pause_circle_filled,
            size: 40,
            color: ColorConstants.walterWhite,
          ),
          crossFadeState:
              ref.watch(audioPlayPauseStateProvider) == PLAY_PAUSE_AUDIO.PLAY
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: Duration(milliseconds: 500),
        ),
      ),
    );
  }
}
