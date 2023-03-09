import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
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
    var downloadFileKey = '${sessionModel.id}-${file.id}';
    if (isDownloaded) {
      return LabelsComponent(
        bgColor: ColorConstants.walterWhite,
        textColor: ColorConstants.greyIsTheNewGrey,
        label: StringConstants.DOWNLOADED.toUpperCase(),
        onTap: () => {},
      );
    } else {
      if (downloadAudioProvider.downloadingProgress[downloadFileKey] != null) {
        return showDownloadProgress(
            getDownloadProgress(downloadAudioProvider, downloadFileKey));
      } else {
        return LabelsComponent(
          label: StringConstants.DOWNLOAD.toUpperCase(),
          // onTap: () async => await downloadAudioProvider.deleteSessionAudio(
          //     '${sessionModel.id}-${file.id}'),

          onTap: () async {
            // await downloadAudioProvider.downloadSessionAudio(
            //     sessionModel, file);

          
          },
        );
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

  double getDownloadProgress(
      AudioDownloaderViewModel downloadAudioProvider, String downloadFileKey) {
    return downloadAudioProvider.downloadingProgress[downloadFileKey]! / 100;
  }
}
