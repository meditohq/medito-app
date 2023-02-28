import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class PlayerButtonsComponent extends ConsumerWidget {
  const PlayerButtonsComponent({super.key, required this.file});
  final SessionFilesModel file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(),
        SizedBox(width: 35),
        _playPauseButton(),
        SizedBox(width: 35),
        _forwardButton()
      ],
    );
  }

  InkWell _rewindButton() {
    return InkWell(
      onTap: () => {},
      child: SvgPicture.asset(
        AssetConstants.icReplay10,
      ),
    );
  }

  InkWell _forwardButton() {
    return InkWell(
      onTap: () => {},
      child: SvgPicture.asset(
        AssetConstants.icForward30,
      ),
    );
  }

  Consumer _playPauseButton() {
    return Consumer(
      builder: (context, ref, child) {
        final audioProviver = ref.watch(audioPlayerNotifierProvider);
        var isPlaying = audioProviver.sessionAudioPlayer.playerState.playing;
        return InkWell(
          onTap: () {
            if (isPlaying) {
              audioProviver.pauseSessionAudio();
            } else {
              audioProviver.playSessionAudio();
            }
          },
          child: AnimatedCrossFade(
            firstChild: Icon(
              Icons.play_circle_fill,
              size: 80,
            ),
            secondChild: Icon(
              Icons.pause_circle_filled,
              size: 80,
            ),
            crossFadeState: isPlaying
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}
