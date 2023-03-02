import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/player/audio_position_viewmodel.dart';
import 'package:Medito/view_model/player/player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class PlayerButtonsComponent extends ConsumerWidget {
  const PlayerButtonsComponent({super.key, required this.file});
  final SessionFilesModel file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isPlaying =
        ref.watch(playPauseAudioProvider(action: PLAY_PAUSE_AUDIO.PLAY));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(ref),
        SizedBox(width: 35),
        _playPauseButton(ref, isPlaying),
        SizedBox(width: 35),
        _forwardButton(ref)
      ],
    );
  }

  InkWell _rewindButton(WidgetRef ref) {
    return InkWell(
      onTap: () =>
          ref.read(skipAudioProvider(skip: SKIP_AUDIO.SKIP_BACWARD_10)),
      child: SvgPicture.asset(
        AssetConstants.icReplay10,
      ),
    );
  }

  InkWell _forwardButton(WidgetRef ref) {
    return InkWell(
      onTap: () =>
          ref.read(skipAudioProvider(skip: SKIP_AUDIO.SKIP_FORWARD_30)),
      child: SvgPicture.asset(
        AssetConstants.icForward30,
      ),
    );
  }

  InkWell _playPauseButton(WidgetRef ref, bool isPlaying) {
    return InkWell(
      onTap: () {
        ref.read(
          playPauseAudioProvider(
              action:
                  isPlaying ? PLAY_PAUSE_AUDIO.PAUSE : PLAY_PAUSE_AUDIO.PLAY),
        );
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
        crossFadeState:
            isPlaying ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: Duration(milliseconds: 500),
      ),
    );
  }
}
