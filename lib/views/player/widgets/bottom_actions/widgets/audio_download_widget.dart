import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Medito/providers/providers.dart';
import 'labels_widget.dart';

class AudioDownloadWidget extends ConsumerWidget {
  const AudioDownloadWidget({
    required this.trackModel,
    required this.file,
    super.key,
  });
  final TrackModel trackModel;
  final TrackFilesModel file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadAudioProvider = ref.watch(audioDownloaderProvider);
    var downloadFileKey =
        '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

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
        onTap: () => _handleDownload(downloadAudioProvider, context),
      );
    }
  }

  Expanded showDownloadProgress(
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
  ) {
    return Expanded(
      child: Container(
        height: 44,
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
    BuildContext context,
  ) async {
    try {
      await downloadAudioProvider.downloadTrackAudio(
        trackModel,
        file,
      );
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
      await downloadAudioProvider.deleteTrackAudio(
        '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}',
      );
      ref.read(deleteTrackFromPreferenceProvider(
        file: file,
      ));
    } catch (e) {
      createSnackBar(e.toString(), context);
    }
  }
}
