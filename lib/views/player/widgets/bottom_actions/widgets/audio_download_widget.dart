// ignore_for_file: use_build_context_synchronously

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

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
    final downloadAudioState = ref.watch(audioDownloaderProvider);
    var downloadFileKey =
        '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: _buildDownloadWidget(
          context,
          ref,
          downloadAudioState,
          downloadFileKey,
        ),
      ),
    );
  }

  Widget _buildDownloadWidget(
    BuildContext context,
    WidgetRef ref,
    AudioDownloaderState downloadAudioState,
    String downloadFileKey,
  ) {
    var isDownloaded =
        downloadAudioState.audioDownloadState[downloadFileKey] ==
            AudioDownloadState.downloaded;
    var isDownloading =
        downloadAudioState.audioDownloadState[downloadFileKey] ==
            AudioDownloadState.downloading;

    return Container(
      decoration: isDownloaded
          ? BoxDecoration(
              color: ColorConstants.graphite.withAlpha(200),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: _buildDownloadContent(downloadAudioState, downloadFileKey,
          isDownloaded, isDownloading, context, ref),
    );
  }

  Widget _buildDownloadContent(
    AudioDownloaderState downloadAudioState,
    String downloadFileKey,
    bool isDownloaded,
    bool isDownloading,
    BuildContext context,
    WidgetRef ref,
  ) {
    if (isDownloaded) {
      return IconButton(
        onPressed: () => _handleRemoveDownload(ref, context),
        tooltip: AppLocalizations.of(context)!.deleteDownload,
        icon: const MeditoIcon(
          assetName: MeditoIcons.downloadCircleSolid,
          color: ColorConstants.white,
        ),
      );
    } else if (isDownloading) {
      return showDownloadProgress(
          downloadAudioState, downloadFileKey, context);
    } else {
      return IconButton(
        onPressed: () => _handleDownload(ref, context),
        tooltip: AppLocalizations.of(context)!.downloadAudio,
        icon: const MeditoIcon(
          assetName: MeditoIcons.downloadCircle,
          color: ColorConstants.white,
        ),
      );
    }
  }

  Widget showDownloadProgress(
    AudioDownloaderState downloadAudioState,
    String downloadFileKey,
    BuildContext context,
  ) {
    var progress = _getDownloadProgress(downloadAudioState, downloadFileKey);

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
    AudioDownloaderState downloadAudioState,
    String downloadFileKey,
  ) {
    if (downloadAudioState.downloadingProgress[downloadFileKey] != null) {
      return downloadAudioState.downloadingProgress[downloadFileKey]! / 100;
    }

    return 0;
  }

  Future<void> _handleDownload(
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      await ref.read(audioDownloaderProvider.notifier).downloadTrackAudio(
        trackModel,
        file,
      );
    } catch (e) {
      showSnackBar(
        context,
        e.toString(),
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _handleRemoveDownload(
    WidgetRef ref,
    BuildContext context,
  ) async {
    var confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return MeditoDialog(
          title: AppLocalizations.of(context)!.confirmDeletionFromPlayerTitle,
          content: MeditoDialogBody(
            '${AppLocalizations.of(context)!.confirmDeletionFromPlayerMessage} "${trackModel.title}"?',
          ),
          actions: [
            MeditoDialogSecondaryButton(
              label: AppLocalizations.of(context)!.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            MeditoDialogDestructiveButton(
              label: AppLocalizations.of(context)!.delete,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await ref.read(audioDownloaderProvider.notifier).deleteTrackAudio(
          '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}',
        );
        ref.read(deleteTrackFromPreferenceProvider(
          file: file,
        ));
      } catch (e) {
        showSnackBar(
          context,
          e.toString(),
          backgroundColor: Colors.red,
        );
      }
    }
  }
}
