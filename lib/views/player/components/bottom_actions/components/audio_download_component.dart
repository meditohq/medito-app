import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Medito/view_model/player/audio_downloader_viewmodel.dart';

import 'labels_component.dart';

class AudioDownloadComponent extends ConsumerWidget {
  const AudioDownloadComponent(
      {required this.sessionModel,
      required this.file,
      required this.isDownloaded,
      super.key});
  final bool isDownloaded;
  final SessionModel sessionModel;
  final SessionFilesModel file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadAudioProvider = ref.watch(audioDownloaderProvider);
    if (isDownloaded) {
      return LabelsComponent(
        bgColor: ColorConstants.walterWhite,
        textColor: ColorConstants.greyIsTheNewGrey,
        label: StringConstants.DOWNLOADED.toUpperCase(),
        onTap: () => {},
      );
    } else {
      if (downloadAudioProvider.downloadingProgress == 0.0) {
        return LabelsComponent(
          label: StringConstants.DOWNLOAD.toUpperCase(),
          // onTap: () async => await downloadAudioProvider.deleteSessionAudio(
          //     '${sessionModel.id}-${file.id}'),
          onTap: () async => await downloadAudioProvider.downloadSessionAudio(
              sessionModel, file),
        );
      } else {
        return showDownloadProgress(downloadAudioProvider.downloadingProgress/100);
      }
    }
  }

  Expanded showDownloadProgress(double downloadingProgress) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: ColorConstants.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(
            Radius.circular(3),
          ),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: LinearProgressIndicator(
          value: downloadingProgress,
        ),
      ),
    );
  }
}
