import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'labels_widget.dart';

class BgSoundWidget extends ConsumerWidget {
  const BgSoundWidget({
    super.key,
    required this.trackModel,
    required this.file,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBgSound =
        ref.watch(backgroundSoundsNotifierProvider).selectedBgSound;
    var checkIsBgSoundSelected = selectedBgSound != null &&
        selectedBgSound.title != StringConstants.none;

    return LabelsWidget(
      label: StringConstants.sound.toUpperCase(),
      bgColor: checkIsBgSoundSelected
          ? ColorConstants.walterWhite
          : ColorConstants.onyx,
      textColor: checkIsBgSoundSelected
          ? ColorConstants.onyx
          : ColorConstants.walterWhite,
      onTap: () {
        context.push(
          RouteConstants.backgroundSoundsPath,
          extra: {'trackModel': trackModel, 'file': file},
        );
      },
    );
  }
}
