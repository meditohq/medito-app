import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/views/player/widgets/bottom_actions/widgets/audio_speed_widget.dart';
import 'package:flutter/material.dart';
import 'widgets/audio_download_widget.dart';
import 'widgets/bg_sound_widget.dart';

class BottomActionWidget extends StatelessWidget {
  const BottomActionWidget({
    super.key,
    required this.meditationModel,
    required this.file,
  });
  final MeditationModel meditationModel;
  final MeditationFilesModel file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          AudioSpeedWidget(),
          width8,
          AudioDownloadWidget(
            meditationModel: meditationModel,
            file: file,
          ),
          width8,
          if (meditationModel.hasBackgroundSound)
            BgSoundWidget(
              meditationModel: meditationModel,
              file: file,
            ),
          if (meditationModel.hasBackgroundSound) width8,
        ],
      ),
    );
  }
}
