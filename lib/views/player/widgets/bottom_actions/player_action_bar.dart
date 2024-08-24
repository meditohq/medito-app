import 'package:flutter/material.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';

import '../../../../models/track/track_model.dart';
import 'bottom_action_bar.dart';
import 'widgets/mark_favourite_widget.dart';

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
        MarkFavouriteWidget(trackModel: trackModel, file: file),
      ],
    );
  }
}
