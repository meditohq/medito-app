import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Medito/providers/providers.dart';
import 'labels_widget.dart';

class AudioDownloadWidget extends ConsumerWidget {
  const AudioDownloadWidget({
    required this.meditationModel,
    required this.file,
    super.key,
  });
  final MeditationModel meditationModel;
  final MeditationFilesModel file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadAudioProvider = ref.watch(audioDownloaderProvider);
    var downloadFileKey =
        '${meditationModel.id}-${file.id}${getFileExtension(file.path)}';

    if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
        AUDIO_DOWNLOAD_STATE.DOWNLOADED) {
      return LabelsWidget(
        bgColor: ColorConstants.walterWhite,
        textColor: ColorConstants.greyIsTheNewGrey,
        label: StringConstants.downloaded.toUpperCase(),
        onTap: () => _handleRemoveDownload(downloadAudioProvider, ref, context),
      );
    } else if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
        AUDIO_DOWNLOAD_STATE.DOWNLOADIING) {
      return showDownloadProgress(downloadAudioProvider, downloadFileKey);
    } else {
      return LabelsWidget(
        label: StringConstants.download.toUpperCase(),
        onTap: () => _handleDownload(downloadAudioProvider, ref, context),
      );
    }
  }

  Expanded showDownloadProgress(
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
  ) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: ColorConstants.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(
            Radius.circular(14),
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
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
  ) {
    if (downloadAudioProvider.downloadingProgress[downloadFileKey] != null) {
      return downloadAudioProvider.downloadingProgress[downloadFileKey]! / 100;
    }

    return 0;
  }

  Future<void> _handleDownload(
    AudioDownloaderProvider downloadAudioProvider,
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      await downloadAudioProvider.downloadMeditationAudio(
        meditationModel,
        file,
      );
      await ref.read(addSingleMeditationInPreferenceProvider(
        meditationModel: meditationModel,
        file: file,
      ).future);
    } catch (e) {
      createSnackBar(e.toString(), context);
    }
  }

  Future<void> _handleRemoveDownload(
    AudioDownloaderProvider downloadAudioProvider,
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      await downloadAudioProvider.deleteMeditationAudio(
        '${meditationModel.id}-${file.id}${getFileExtension(file.path)}',
      );
      ref.read(deleteMeditationFromPreferenceProvider(
        file: file,
      ));
    } catch (e) {
      createSnackBar(e.toString(), context);
    }
  }
}
