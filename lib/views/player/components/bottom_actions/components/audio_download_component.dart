import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/view_model/session/session_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Medito/view_model/player/download/audio_downloader_viewmodel.dart';

import 'labels_component.dart';

class AudioDownloadComponent extends ConsumerWidget {
  const AudioDownloadComponent(
      {required this.sessionModel, required this.file, super.key});
  final SessionModel sessionModel;
  final SessionFilesModel file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadAudioProvider = ref.watch(audioDownloaderProvider);
    var downloadFileKey = '${sessionModel.id}-${file.id}';

    if (downloadAudioProvider.audioDownloadState ==
        AUDIO_DOWNLOAD_STATE.DOWNLOADED) {
      return LabelsComponent(
        bgColor: ColorConstants.walterWhite,
        textColor: ColorConstants.greyIsTheNewGrey,
        label: StringConstants.DOWNLOADED.toUpperCase(),
        onTap: () async =>
            await _handleRemoveDownload(downloadAudioProvider, ref, context),
      );
    } else if (downloadAudioProvider.audioDownloadState ==
        AUDIO_DOWNLOAD_STATE.DOWNLOADIING) {
      return showDownloadProgress(downloadAudioProvider, downloadFileKey);
    } else {
      return LabelsComponent(
          label: StringConstants.DOWNLOAD.toUpperCase(),
          onTap: () async =>
              await _handleDownload(downloadAudioProvider, ref, context));
    }
  }

  Expanded showDownloadProgress(
      AudioDownloaderViewModel downloadAudioProvider, String downloadFileKey) {
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
          value: _getDownloadProgress(downloadAudioProvider, downloadFileKey),
        ),
      ),
    );
  }

  double _getDownloadProgress(
      AudioDownloaderViewModel downloadAudioProvider, String downloadFileKey) {
    if (downloadAudioProvider.downloadingProgress[downloadFileKey] != null) {
      return downloadAudioProvider.downloadingProgress[downloadFileKey]! / 100;
    }
    return 0;
  }

  Future<void> _handleDownload(AudioDownloaderViewModel downloadAudioProvider,
      WidgetRef ref, BuildContext context) async {
    try {
      await downloadAudioProvider.downloadSessionAudio(sessionModel, file);
      await ref.read(addSingleSessionInPreferenceProvider(
              sessionModel: sessionModel, file: file)
          .future);
    } catch (e) {
      createSnackBar(e.toString(), context);
    }
  }

  Future<void> _handleRemoveDownload(
      AudioDownloaderViewModel downloadAudioProvider,
      WidgetRef ref,
      BuildContext context) async {
    try {
      await downloadAudioProvider.deleteSessionAudio(
          '${sessionModel.id}-${file.id}${getFileExtension(file.path)}');
      ref.read(deleteSessionFromPreferenceProvider(
          sessionModel: sessionModel, file: file));
    } catch (e) {
      createSnackBar(e.toString(), context);
    }
  }
}
