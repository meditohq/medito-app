import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: ColorConstants.greyIsTheNewGrey,
      child: ListTile(
        horizontalTitleGap: 15,
        isThreeLine: false,
        leading: sessionCoverImage(
            'https://staging.medito.app/v1/files/images/sessions/9.png'),
        title: _title(context, 'Gratitude for nature'),
        subtitle: _subtitle(context),
        trailing: _playPauseButton(),
      ),
    );
  }

  SizedBox sessionCoverImage(String url) {
    return SizedBox(
      height: 40,
      width: 40,
      child: NetworkImageComponent(url: url),
    );
  }

  Text _title(BuildContext context, String title) {
    return Text(
      title,
      textAlign: TextAlign.left,
      style: Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
          fontFamily: ClashDisplay,
          color: ColorConstants.walterWhite,
          fontSize: 16,
          letterSpacing: 1),
    );
  }

  SizedBox _subtitle(BuildContext context) {
    return SizedBox(
      height: 15,
      child: MarkdownComponent(
        body:
            'Osama Asif https://stackoverflow.com/questions/64684732/v1/files/images/sessions/9.png',
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

  InkWell _playPauseButton() {
    return InkWell(
      onTap: () {
        // var _state = ref.watch(audioPlayPauseStateProvider.notifier).state;

        // ref.read(audioPlayPauseStateProvider.notifier).state =
        //     _state == PLAY_PAUSE_AUDIO.PAUSE
        //         ? PLAY_PAUSE_AUDIO.PLAY
        //         : PLAY_PAUSE_AUDIO.PAUSE;
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
        crossFadeState: CrossFadeState.showFirst,
        duration: Duration(milliseconds: 500),
      ),
    );
  }
}
