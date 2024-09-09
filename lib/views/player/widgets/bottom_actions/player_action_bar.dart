import 'package:medito/constants/constants.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';
import 'package:flutter/material.dart';

import '../../../../models/track/track_model.dart';
import 'bottom_action_bar.dart';

class PlayerActionBar extends StatelessWidget {
  const PlayerActionBar({
    super.key,
    required this.trackModel,
    required this.file,
    required this.isBackgroundSoundSelected,
    required this.onSpeedChanged,
    required this.onClosePressed,
  });

  final bool isBackgroundSoundSelected;
  final TrackModel trackModel;
  final TrackFilesModel file;
  final Function(double) onSpeedChanged;
  final void Function() onClosePressed;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      showBackground: true,
      actions: [
        GestureDetector(
          onTap: onClosePressed,
          child: Icon(
            Icons.close,
            color: ColorConstants.walterWhite,
          ),
        ),
        AudioDownloadWidget(
          trackModel: trackModel,
          file: file,
        ),
        if (trackModel.hasBackgroundSound)
          BgSoundWidget(
            isBackgroundSoundSelected: isBackgroundSoundSelected,
            trackModel: trackModel,
            file: file,
          ),
        AudioSpeedWidget(onSpeedChanged: onSpeedChanged),
      ],
    );
  }
}
