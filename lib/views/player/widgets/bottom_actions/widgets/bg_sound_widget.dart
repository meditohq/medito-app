import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/track/track_model.dart';
import '../../../../background_sound/background_sound_view.dart';

class BgSoundWidget extends ConsumerWidget {
  const BgSoundWidget({
    super.key,
    required this.trackModel,
    required this.file,
    required this.isBackgroundSoundSelected,
  });

  final TrackModel trackModel;
  final TrackFilesModel file;
  final bool isBackgroundSoundSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BackgroundSoundView(),
          ),
        );
      },
      icon: Icon(
        Icons.music_note,
        color: isBackgroundSoundSelected
            ? ColorConstants.lightPurple
            : ColorConstants.white,
      ),
    );
  }
}
