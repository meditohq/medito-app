import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      return IconButton(
        onPressed: () =>
            _handleRemoveDownload(downloadAudioProvider, ref, context),
        icon: Icon(
          Icons.downloading_outlined,
          color: ColorConstants.lightPurple,
        ),
      );
    } else if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
        AUDIO_DOWNLOAD_STATE.DOWNLOADIING) {
      return showDownloadProgress(downloadAudioProvider, downloadFileKey);
    } else {
      return IconButton(
        onPressed: () => _handleDownload(downloadAudioProvider, context),
        icon: Icon(
          Icons.downloading_outlined,
        ),
      );
    }
  }

  Stack showDownloadProgress(
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.downloading,
          size: 24,
        ),
        SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            value: _getDownloadProgress(downloadAudioProvider, downloadFileKey),
          ),
        ),
      ],
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
