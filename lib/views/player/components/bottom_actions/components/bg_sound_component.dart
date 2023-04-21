import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'labels_component.dart';

class BgSoundComponent extends ConsumerWidget {
  const BgSoundComponent({
    super.key,
    required this.sessionModel,
    required this.file,
  });
  final SessionModel sessionModel;
  final SessionFilesModel file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBgSound =
        ref.watch(backgroundSoundsNotifierProvider).selectedBgSound;
    var checkIsBgSoundSelected = selectedBgSound != null &&
        selectedBgSound.title != StringConstants.NONE;

    return LabelsComponent(
      label: StringConstants.SOUND.toUpperCase(),
      bgColor: checkIsBgSoundSelected
          ? ColorConstants.walterWhite
          : ColorConstants.greyIsTheNewGrey,
      textColor: checkIsBgSoundSelected
          ? ColorConstants.greyIsTheNewGrey
          : ColorConstants.walterWhite,
      onTap: () {
        context.push(
          RouteConstants.backgroundSoundsPath,
          extra: {'sessionModel': sessionModel, 'file': file},
        );
        ref.read(pageviewNotifierProvider).gotoPreviousPage();
      },
    );
  }
}
