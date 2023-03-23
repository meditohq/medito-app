import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/strings/asset_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/player/audio_play_pause_viewmodel.dart';
import 'package:Medito/view_model/player/audio_position_viewmodel.dart';
import 'package:Medito/view_model/player/player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class PlayerButtonsComponent extends ConsumerWidget {
  const PlayerButtonsComponent(
      {super.key, required this.sessionModel, required this.file});
  final SessionFilesModel file;
  final SessionModel sessionModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioPlayPauseProvider(sessionModel.hasBackgroundSound));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _rewindButton(ref),
        SizedBox(width: 35),
        _playPauseButton(ref),
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

  InkWell _playPauseButton(WidgetRef ref) {
    return InkWell(
      onTap: () async => await _handleTap(ref),
      child: AnimatedCrossFade(
        firstChild: Icon(
          Icons.play_circle_fill,
          size: 72,
          color: ColorConstants.walterWhite,
        ),
        secondChild: Icon(
          Icons.pause_circle_filled,
          size: 72,
          color: ColorConstants.walterWhite,
        ),
        crossFadeState:
            ref.watch(audioPlayPauseStateProvider) == PLAY_PAUSE_AUDIO.PLAY
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _handleTap(WidgetRef ref) async {
    var _state = ref.watch(audioPlayPauseStateProvider.notifier).state;
    ref.read(audioPlayPauseStateProvider.notifier).state =
        _state == PLAY_PAUSE_AUDIO.PAUSE
            ? PLAY_PAUSE_AUDIO.PLAY
            : PLAY_PAUSE_AUDIO.PAUSE;
  }
}
