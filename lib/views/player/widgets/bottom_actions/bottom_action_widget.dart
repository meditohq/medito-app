import 'package:Medito/constants/constants.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';
import 'package:flutter/material.dart';

import '../../../../models/track/track_model.dart';
import 'widgets/mark_favourite_widget.dart';

class BottomActionWidget extends StatelessWidget {
  const BottomActionWidget({
    super.key,
    required this.trackModel,
    required this.file,
    required this.isBackgroundSoundSelected,
    required this.onSpeedChanged,
  });

  final bool isBackgroundSoundSelected;
  final TrackModel trackModel;
  final TrackFilesModel file;
  final Function(double) onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: AudioDownloadWidget(
              trackModel: trackModel,
              file: file,
            ),
          ),
          width8,
          if (trackModel.hasBackgroundSound)
            Expanded(
              child: BgSoundWidget(
                isBackgroundSoundSelected: isBackgroundSoundSelected,
                trackModel: trackModel,
                file: file,
              ),
            ),
          if (trackModel.hasBackgroundSound) width8,
          Expanded(child: AudioSpeedWidget(onSpeedChanged: onSpeedChanged)),
          width8,
          Expanded(
            child: MarkFavouriteWidget(),
          ),
        ],
      ),
    );
  }
}
