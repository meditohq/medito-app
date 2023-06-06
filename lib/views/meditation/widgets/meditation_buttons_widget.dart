import 'dart:async';
import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/network/cache.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeditationButtonsWidget extends StatelessWidget {
  final MeditationModel meditationModel;
  const MeditationButtonsWidget({super.key, required this.meditationModel});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: meditationModel.audio.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meditationModel.audio[i].guideName,
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                    color: ColorConstants.walterWhite,
                  ),
            ),
            height8,
            _gridList(i),
            SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Wrap _gridList(
    int i,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children:
          meditationModel.audio[i].files.map((e) => _getGridItem(e)).toList(),
    );
  }

  Consumer _getGridItem(
    MeditationFilesModel file,
  ) {
    return Consumer(
      builder: (context, ref, child) => InkWell(
        onTap: () {
          var dataMap = {
            'secsListened': (Duration(milliseconds: file.duration).inSeconds),
            'id': '${meditationModel.id}',
          };
          unawaited(writeJSONToCache(encoded(dataMap), STATS));
          ref
              .read(playerProvider.notifier)
              .addCurrentlyPlayingMeditationInPreference(
                meditationModel: meditationModel,
                file: file,
              );
          ref.read(pageviewNotifierProvider).gotoNextPage();
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 171,
          height: 56,
          decoration: BoxDecoration(
            color: ColorConstants.greyIsTheNewGrey,
            borderRadius: BorderRadius.all(
              Radius.circular(14),
            ),
          ),
          child: Center(
            child: Text(
              '${convertDurationToMinutes(milliseconds: file.duration)} mins',
              style: Theme.of(context).primaryTextTheme.bodyLarge?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: DmMono,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
