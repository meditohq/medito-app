import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/views/player/components/bottom_actions/components/audio_speed_component.dart';
import 'package:Medito/views/player/components/bottom_actions/components/labels_component.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomActionComponent extends StatelessWidget {
  const BottomActionComponent(
      {super.key, required this.sessionModel, required this.file});
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
          LabelsComponent(
            label: StringConstants.DOWNLOAD.toUpperCase(),
            onTap: () => {},
          ),
          width8,
          if (sessionModel.hasBackgroundSound)
            LabelsComponent(
              label: StringConstants.SOUND.toUpperCase(),
              onTap: () => _handleOnTapSound(context),
            ),
          if (sessionModel.hasBackgroundSound) width8,
        ],
      ),
    );
  }

  void _handleOnTapSound(BuildContext context) {
    var location = GoRouter.of(context).location;
    context.go(
      location + backgroundSounds,
      extra: {'sessionModel': sessionModel, 'file': file},
    );
  }
}
