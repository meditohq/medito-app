import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/player/download/audio_downloader_provider.dart';
import 'package:medito/services/downloads/background_download_service.dart';
import 'package:medito/utils/logger.dart';

final backgroundDownloadProvider = Provider<AutomaticDownloadQueue>((ref) {
  final audio = ref.watch(audioDownloaderProvider.notifier);
  final settings = ref.read(downloadSettingsProvider);
  final service = BackgroundDownloadService(
    downloader: FileDownloader(),
    enabled: settings.downloadNext,
    requiresWiFi: !settings.useMobileData,
    onCompleted: (request) async {
      if (!ref.mounted) {
        throw StateError('Downloads have not been restored yet');
      }
      await audio.saveDownloadedRequest(request);
    },
    onStatus: (request, status, progress) {
      if (!ref.mounted) return;
      // Completion becomes visible only after its metadata is persisted.
      if (status == TaskStatus.complete) return;
      audio.reportBackgroundDownload(
        request,
        status.isFinalState
            ? AudioDownloadState.download
            : AudioDownloadState.downloading,
        progress: progress,
      );
    },
  );
  ref.listen(downloadSettingsProvider, (previous, next) {
    unawaited(
      service
          .configure(
            enabled: next.downloadNext,
            requiresWiFi: !next.useMobileData,
          )
          .catchError((Object error) {
            AppLogger.e(
              'BACKGROUND_DOWNLOAD',
              'Could not change download settings',
              error,
            );
          }),
    );
  });
  unawaited(
    service.ready.catchError((Object error) {
      AppLogger.e('BACKGROUND_DOWNLOAD', 'Could not restore downloads', error);
    }),
  );
  ref.onDispose(service.dispose);
  return service;
});
