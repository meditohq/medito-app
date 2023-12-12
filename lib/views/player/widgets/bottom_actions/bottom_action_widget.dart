import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:flutter/material.dart';

import 'widgets/audio_download_widget.dart';
import 'widgets/bg_sound_widget.dart';
import 'widgets/mark_favourite_widget.dart';

class BottomActionWidget extends StatelessWidget {
  const BottomActionWidget({
    super.key,
    required this.trackModel,
    required this.file,
  });

  final TrackModel trackModel;
  final TrackFilesModel file;

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
                trackModel: trackModel,
                file: file,
              ),
            ),
          if (trackModel.hasBackgroundSound) width8,
          Expanded(child: AudioSpeedWidget()),
          width8,
          Expanded(
            child: MarkFavouriteWidget(
              trackModel: trackModel,
              file: file,
            ),
          ),
        ],
      ),
    );
  }
}
