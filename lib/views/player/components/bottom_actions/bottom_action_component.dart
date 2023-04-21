import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/views/player/components/bottom_actions/components/audio_speed_component.dart';
import 'package:flutter/material.dart';
import 'components/audio_download_component.dart';
import 'components/bg_sound_component.dart';

class BottomActionComponent extends StatelessWidget {
  const BottomActionComponent({
    super.key,
    required this.sessionModel,
    required this.file,
  });
  final SessionModel sessionModel;
  final SessionFilesModel file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          AudioSpeedComponent(),
          width8,
          AudioDownloadComponent(
            sessionModel: sessionModel,
            file: file,
          ),
          width8,
          if (sessionModel.hasBackgroundSound)
            BgSoundComponent(
              sessionModel: sessionModel,
              file: file,
            ),
          if (sessionModel.hasBackgroundSound) width8,
        ],
      ),
    );
  }
}
