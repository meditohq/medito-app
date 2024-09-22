import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/utils.dart';
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

    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: _buildDownloadWidget(context, ref, downloadAudioProvider, downloadFileKey),
      ),
    );
  }

  Widget _buildDownloadWidget(BuildContext context, WidgetRef ref, AudioDownloaderProvider downloadAudioProvider, String downloadFileKey) {
    if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
        AudioDownloadState.DOWNLOADED) {
      return IconButton(
        onPressed: () =>
            _handleRemoveDownload(downloadAudioProvider, ref, context),
        icon: const Icon(
          Icons.downloading_outlined,
          color: ColorConstants.lightPurple,
        ),
      );
    } else if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
        AudioDownloadState.DOWNLOADING) {
      return showDownloadProgress(downloadAudioProvider, downloadFileKey);
    } else {
      return IconButton(
        onPressed: () => _handleDownload(downloadAudioProvider, context),
        icon: const Icon(
          Icons.downloading_outlined,
        ),
      );
    }
  }

  Widget showDownloadProgress(
      AudioDownloaderProvider downloadAudioProvider,
      String downloadFileKey,
      ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
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
    var confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(StringConstants.confirmDeletionTitle),
          content: Text('${StringConstants.confirmDeletionMessage} "${trackModel.title}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // User pressed the cancel button
              },
              child: const Text(StringConstants.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User pressed the delete button
              },
              child: const Text(StringConstants.delete),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
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
}