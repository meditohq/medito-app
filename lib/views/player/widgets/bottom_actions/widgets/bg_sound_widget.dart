import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../models/track/track_model.dart';

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
        context.push(
          RouteConstants.backgroundSoundsPath,
          extra: {'trackModel': trackModel, 'file': file},
        );
      },
      icon: Icon(
        Icons.music_note,
        color: isBackgroundSoundSelected
            ? ColorConstants.lightPurple
            : ColorConstants.walterWhite,
      ),
    );
  }
}
