// ignore_for_file: use_build_context_synchronously

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

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
        child: _buildDownloadWidget(
          context,
          ref,
          downloadAudioProvider,
          downloadFileKey,
        ),
      ),
    );
  }

  Widget _buildDownloadWidget(
    BuildContext context,
    WidgetRef ref,
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
  ) {
    var isDownloaded =
        downloadAudioProvider.audioDownloadState[downloadFileKey] ==
            AudioDownloadState.downloaded;
    var isDownloading =
        downloadAudioProvider.audioDownloadState[downloadFileKey] ==
            AudioDownloadState.downloading;

    return Container(
      decoration: isDownloaded
          ? BoxDecoration(
              color: ColorConstants.graphite.withAlpha(200),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: _buildDownloadContent(downloadAudioProvider, downloadFileKey,
          isDownloaded, isDownloading, context, ref),
    );
  }

  Widget _buildDownloadContent(
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
    bool isDownloaded,
    bool isDownloading,
    BuildContext context,
    WidgetRef ref,
  ) {
    if (isDownloaded) {
      return IconButton(
        onPressed: () =>
            _handleRemoveDownload(downloadAudioProvider, ref, context),
        icon: const MeditoIcon(
          assetName: MeditoIcons.downloadCircleSolid,
          color: ColorConstants.white,
        ),
      );
    } else if (isDownloading) {
      return showDownloadProgress(
          downloadAudioProvider, downloadFileKey, context);
    } else {
      return IconButton(
        onPressed: () => _handleDownload(downloadAudioProvider, context),
        icon: const MeditoIcon(
          assetName: MeditoIcons.downloadCircle,
          color: ColorConstants.white,
        ),
      );
    }
  }

  Widget showDownloadProgress(
    AudioDownloaderProvider downloadAudioProvider,
    String downloadFileKey,
    BuildContext context,
  ) {
    var progress = _getDownloadProgress(downloadAudioProvider, downloadFileKey);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: ColorConstants.graphite.withAlpha(100),
          ),
        ),
        // Progress fill from bottom to top
        Positioned(
          bottom: 0,
          child: Container(
            width: 48,
            height: 48 * progress,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: ColorConstants.graphite.withAlpha(200),
            ),
          ),
        ),
        // Loading spinner icon
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(ColorConstants.white),
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
          title: Text(
              AppLocalizations.of(context)!.confirmDeletionFromPlayerTitle),
          content: Text(
            '${AppLocalizations.of(context)!.confirmDeletionFromPlayerMessage} "${trackModel.title}"?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // User pressed the cancel button
                Navigator.of(context).pop(false);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                // User pressed the delete button
                Navigator.of(context).pop(true);
              },
              child: Text(AppLocalizations.of(context)!.delete),
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
