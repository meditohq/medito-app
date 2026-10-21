import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';

enum BatchDownloadStatus {
  idle,
  fetchingTracks,
  downloading,
  completed,
  error,
}

class BatchDownloadState {
  final BatchDownloadStatus status;
  final String? packId;
  final int completed;
  final int total;
  final String? errorMessage;

  const BatchDownloadState({
    this.status = BatchDownloadStatus.idle,
    this.packId,
    this.completed = 0,
    this.total = 0,
    this.errorMessage,
  });

  bool get isDownloading =>
      status == BatchDownloadStatus.fetchingTracks ||
      status == BatchDownloadStatus.downloading;

  bool isPackDownloading(String id) => isDownloading && packId == id;

  BatchDownloadState copyWith({
    BatchDownloadStatus? status,
    String? packId,
    int? completed,
    int? total,
    String? errorMessage,
  }) =>
      BatchDownloadState(
        status: status ?? this.status,
        packId: packId ?? this.packId,
        completed: completed ?? this.completed,
        total: total ?? this.total,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

final batchDownloadProvider =
    NotifierProvider<BatchDownloadNotifier, BatchDownloadState>(
  BatchDownloadNotifier.new,
);

class BatchDownloadNotifier extends Notifier<BatchDownloadState> {
  bool _cancelled = false;

  @override
  BatchDownloadState build() => const BatchDownloadState();

  Future<void> startPackDownload(PackModel pack) async {
    if (state.isDownloading) return;
    _cancelled = false;

    state = BatchDownloadState(
      status: BatchDownloadStatus.fetchingTracks,
      packId: pack.id,
      completed: 0,
      total: 0,
    );

    unawaited(ref.read(analyticsServiceProvider).logEvent(
      name: AnalyticsEventConstants.packBatchDownloadStarted,
      parameters: {AnalyticsEventConstants.paramPackId: pack.id},
    ));

    final trackItems = pack.items
        .where((item) => item.type == TypeConstants.track)
        .toList();

    if (trackItems.isEmpty) {
      state = const BatchDownloadState(status: BatchDownloadStatus.completed);
      return;
    }

    try {
      final trackRepo = ref.read(trackRepositoryProvider);
      final downloaderRepo = ref.read(downloaderRepositoryProvider);

      final fetchedTracks = <Track>[];
      for (final item in trackItems) {
        try {
          fetchedTracks.add(await trackRepo.fetchTrack(item.id));
        } catch (e) {
          AppLogger.e('BATCH_DOWNLOAD', 'Failed to fetch track ${item.id}: $e');
        }
      }

      if (_cancelled) return;

      if (fetchedTracks.isEmpty) {
        state = state.copyWith(
          status: BatchDownloadStatus.error,
          errorMessage: 'Failed to load tracks for download',
        );
        return;
      }

      final itemsToDownload = <({String url, String fileName})>[];
      final tracksForPreference = <Track>[];

      for (final track in fetchedTracks) {
        if (track.voices.isEmpty) continue;
        final (:voice, :file) = TrackVariantSelector.resolve(track);
        final fileName =
            '${track.id}-${file.id}${getAudioFileExtension(file.path)}';
        final isDownloaded = await downloaderRepo.isFileDownloaded(fileName);

        tracksForPreference.add(Track(
          id: track.id,
          title: track.title,
          description: track.description,
          coverUrl: track.coverUrl,
          isPublished: true,
          hasBackgroundSound: track.hasBackgroundSound,
          artist: track.artist,
          voices: [TrackVoice(guideName: voice.guideName, audioFiles: [file])],
        ));

        if (!isDownloaded) {
          itemsToDownload.add((url: file.path, fileName: fileName));
        }
      }

      if (_cancelled) return;

      final totalItems = tracksForPreference.length;
      final alreadyDownloadedCount = totalItems - itemsToDownload.length;

      if (itemsToDownload.isEmpty) {
        await _saveDownloadedTracksToPreference(tracksForPreference);
        state = state.copyWith(
          status: BatchDownloadStatus.completed,
          completed: totalItems,
          total: totalItems,
        );
        return;
      }

      state = state.copyWith(
        status: BatchDownloadStatus.downloading,
        completed: alreadyDownloadedCount,
        total: totalItems,
      );

      var nextIndex = 0;
      Future<void> worker() async {
        while (nextIndex < itemsToDownload.length) {
          if (_cancelled) return;
          final item = itemsToDownload[nextIndex++];
          await downloaderRepo.downloadFile(item.url, fileName: item.fileName);
          if (_cancelled || !ref.mounted) return;
          state = state.copyWith(completed: state.completed + 1);
        }
      }

      final poolSize = min(4, itemsToDownload.length);
      await Future.wait(List.generate(poolSize, (_) => worker()));

      if (_cancelled || !ref.mounted) return;

      await _saveDownloadedTracksToPreference(tracksForPreference);

      unawaited(ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.packBatchDownloadCompleted,
        parameters: {AnalyticsEventConstants.paramPackId: pack.id},
      ));

      state = state.copyWith(
        status: BatchDownloadStatus.completed,
        completed: totalItems,
        total: totalItems,
      );
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Error during batch download: $e');
      if (ref.mounted) {
        state = state.copyWith(
          status: BatchDownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _saveDownloadedTracksToPreference(List<Track> newTracks) async {
    try {
      final current = await ref.read(downloadedTracksProvider.future);
      final trackMap = {for (final t in current) t.id: t};
      for (final t in newTracks) {
        trackMap.putIfAbsent(t.id, () => t);
      }
      await ref.read(trackRepositoryProvider).addTrackInPreference(trackMap.values.toList());
      ref.invalidate(downloadedTracksProvider);
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Failed saving tracks to preference: $e');
    }
  }

  Future<void> cancelDownload() async {
    if (!state.isDownloading) return;
    _cancelled = true;

    final packId = state.packId;
    if (packId != null) {
      unawaited(ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.packBatchDownloadCancelled,
        parameters: {AnalyticsEventConstants.paramPackId: packId},
      ));
    }

    state = const BatchDownloadState(status: BatchDownloadStatus.idle);
  }

  Future<void> deletePackDownloads(PackModel pack) async {
    final trackIds = pack.items
        .where((item) => item.type == TypeConstants.track)
        .map((item) => item.id)
        .toSet();

    if (trackIds.isEmpty) return;

    try {
      final current = await ref.read(downloadedTracksProvider.future);
      final downloaderRepo = ref.read(downloaderRepositoryProvider);

      for (final track in current.where((t) => trackIds.contains(t.id))) {
        for (final voice in track.voices) {
          for (final file in voice.audioFiles) {
            final fileName =
                '${track.id}-${file.id}${getAudioFileExtension(file.path)}';
            await downloaderRepo.deleteDownloadedFile(fileName);
          }
        }
      }

      final remaining =
          current.where((t) => !trackIds.contains(t.id)).toList();
      await ref.read(trackRepositoryProvider).addTrackInPreference(remaining);
      ref.invalidate(downloadedTracksProvider);

      unawaited(ref.read(analyticsServiceProvider).logEvent(
        name: AnalyticsEventConstants.packBatchDownloadsDeleted,
        parameters: {AnalyticsEventConstants.paramPackId: pack.id},
      ));
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Failed deleting pack downloads: $e');
    }
  }
}

/// Helper extension on PackModel to test whether all of its sessions are downloaded.
extension PackDownloadExtension on PackModel {
  bool isFullyDownloaded(List<Track> downloadedTracks) {
    final trackItems =
        items.where((i) => i.type == TypeConstants.track).toList();
    if (trackItems.isEmpty) return false;
    return trackItems.every(
      (item) => downloadedTracks.any((d) => d.id == item.id),
    );
  }
}
