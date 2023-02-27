import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/view_model/player/audio_speed_viewmodel.dart';
import 'package:Medito/views/player/components/bottom_actions/components/audio_speed_component.dart';
import 'package:Medito/views/player/components/bottom_actions/components/labels_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomActionComponent extends StatelessWidget {
  const BottomActionComponent({super.key, required this.sessionModel});
  final SessionModel sessionModel;
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
            label: 'DONWLOAD',
            onTap: () => {},
          ),
          width8,
          if (sessionModel.hasBackgroundSound)
            LabelsComponent(
              label: 'SOUND',
              onTap: () => {},
            ),
          if (sessionModel.hasBackgroundSound) width8,
        ],
      ),
    );
  }
}
