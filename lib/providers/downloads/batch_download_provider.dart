import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/downloader/download_library.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';

enum BatchDownloadStatus { idle, fetchingTracks, downloading, completed, error }

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
  }) => BatchDownloadState(
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
  Future<void>? _running;
  bool _deleting = false;
  Future<void> _preferenceWrites = Future.value();

  @override
  BatchDownloadState build() => const BatchDownloadState();

  Future<void> startPackDownload(PackModel pack) {
    // Cancellation drains active writes before another batch can reuse the
    // same filenames. Never reset a cancellation flag under an older worker.
    if (_deleting || !pack.canDownloadAll) return Future.value();
    if (_running != null) return _running!;
    _cancelled = false;
    return _running = _downloadPack(pack).whenComplete(() => _running = null);
  }

  Future<void> _downloadPack(PackModel pack) async {
    state = BatchDownloadState(
      status: BatchDownloadStatus.fetchingTracks,
      packId: pack.id,
      completed: 0,
      total: 0,
    );

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.packBatchDownloadStarted,
            parameters: {AnalyticsEventConstants.paramPackId: pack.id},
          ),
    );

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

      var hadFailures = false;
      final fetchedTracks = <Track>[];
      for (final item in trackItems) {
        if (_cancelled || !ref.mounted) return;
        try {
          fetchedTracks.add(await trackRepo.fetchTrack(item.id));
        } catch (e) {
          hadFailures = true;
          AppLogger.e('BATCH_DOWNLOAD', 'Failed to fetch track ${item.id}: $e');
        }
      }

      if (_cancelled || !ref.mounted) return;

      if (fetchedTracks.isEmpty) {
        state = state.copyWith(
          status: BatchDownloadStatus.error,
          errorMessage: 'Failed to load tracks for download',
        );
        return;
      }

      final itemsToDownload = <({String url, String fileName, Track track})>[];
      final tracksForPreference = <Track>[];

      for (final track in fetchedTracks) {
        if (_cancelled || !ref.mounted) return;
        if (track.voices.isEmpty ||
            track.voices.every((v) => v.audioFiles.isEmpty)) {
          hadFailures = true;
          continue;
        }
        final (:voice, :file) = TrackVariantSelector.resolve(
          track.copyWith(
            voices: track.voices.where((v) => v.audioFiles.isNotEmpty).toList(),
          ),
        );
        final fileName =
            '${track.id}-${file.id}${getAudioFileExtension(file.path)}';
        final isDownloaded = await downloaderRepo.isFileDownloaded(fileName);
        if (_cancelled || !ref.mounted) return;

        final downloadedTrack = Track(
          id: track.id,
          title: track.title,
          description: track.description,
          coverUrl: track.coverUrl,
          isPublished: true,
          hasBackgroundSound: track.hasBackgroundSound,
          artist: track.artist,
          voices: [
            TrackVoice(guideName: voice.guideName, audioFiles: [file]),
          ],
        );

        if (!isDownloaded) {
          itemsToDownload.add((
            url: file.path,
            fileName: fileName,
            track: downloadedTrack,
          ));
        } else {
          tracksForPreference.add(downloadedTrack);
        }
      }

      if (_cancelled || !ref.mounted) return;

      final totalItems = trackItems.length;
      final alreadyDownloadedCount = tracksForPreference.length;
      await _saveDownloadedTracksToPreference(tracksForPreference);
      if (_cancelled || !ref.mounted) return;

      if (itemsToDownload.isEmpty) {
        state = state.copyWith(
          status: hadFailures
              ? BatchDownloadStatus.error
              : BatchDownloadStatus.completed,
          completed: alreadyDownloadedCount,
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
          if (_cancelled || !ref.mounted) return;
          final item = itemsToDownload[nextIndex++];
          try {
            await downloaderRepo.downloadFile(
              item.url,
              fileName: item.fileName,
            );
            if (!ref.mounted) return;
            // Keep finished files playable even if another download fails or
            // the user cancels. Preference writes are serialized below.
            await _saveDownloadedTracksToPreference([item.track]);
            if (_cancelled || !ref.mounted) return;
            state = state.copyWith(completed: state.completed + 1);
          } catch (e) {
            hadFailures = true;
            AppLogger.e('BATCH_DOWNLOAD', 'Failed downloading a track: $e');
          }
        }
      }

      final poolSize = min(4, itemsToDownload.length);
      await Future.wait(List.generate(poolSize, (_) => worker()));

      if (_cancelled || !ref.mounted) return;

      if (hadFailures) {
        state = state.copyWith(status: BatchDownloadStatus.error);
        return;
      }

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.packBatchDownloadCompleted,
              parameters: {AnalyticsEventConstants.paramPackId: pack.id},
            ),
      );

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

  Future<void> _saveDownloadedTracksToPreference(List<Track> newTracks) {
    if (newTracks.isEmpty) return Future.value();
    final write = _preferenceWrites.then((_) async {
      if (!ref.mounted) return;
      await ref.read(downloadLibraryProvider).update((current) {
        final trackMap = {for (final t in current) t.id: t};
        for (final t in newTracks) {
          final existing = trackMap[t.id];
          if (existing == null) {
            trackMap[t.id] = t;
            continue;
          }
          final voices = [...existing.voices];
          for (final voice in t.voices) {
            final index = voices.indexWhere(
              (v) => v.guideName == voice.guideName,
            );
            if (index < 0) {
              voices.add(voice);
              continue;
            }
            final files = {
              for (final f in voices[index].audioFiles) f.id: f,
              for (final f in voice.audioFiles) f.id: f,
            };
            voices[index] = voices[index].copyWith(
              audioFiles: files.values.toList(),
            );
          }
          trackMap[t.id] = existing.copyWith(voices: voices);
        }
        return trackMap.values.toList();
      });
      if (ref.mounted) ref.invalidate(downloadedTracksProvider);
    });
    _preferenceWrites = write.catchError((Object error) {
      AppLogger.e(
        'BATCH_DOWNLOAD',
        'Failed saving tracks to preference: $error',
      );
    });
    return write;
  }

  Future<void> cancelDownload() async {
    if (!state.isDownloading) return;
    _cancelled = true;

    final packId = state.packId;
    if (packId != null) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.packBatchDownloadCancelled,
              parameters: {AnalyticsEventConstants.paramPackId: packId},
            ),
      );
    }

    await _running;
    if (ref.mounted) {
      state = const BatchDownloadState(status: BatchDownloadStatus.idle);
    }
  }

  Future<bool> deletePackDownloads(PackModel pack) async {
    final trackIds = pack.items
        .where((item) => item.type == TypeConstants.track)
        .map((item) => item.id)
        .toSet();

    if (trackIds.isEmpty) return true;
    if (_deleting) return false;
    _deleting = true;

    try {
      await _running;
      if (!ref.mounted) return false;
      final current = await ref
          .read(trackRepositoryProvider)
          .fetchTrackFromPreference();
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

      await ref
          .read(downloadLibraryProvider)
          .update(
            (latest) => latest.where((t) => !trackIds.contains(t.id)).toList(),
          );
      if (ref.mounted) ref.invalidate(downloadedTracksProvider);

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.packBatchDownloadsDeleted,
              parameters: {AnalyticsEventConstants.paramPackId: pack.id},
            ),
      );
      return true;
    } catch (e) {
      AppLogger.e('BATCH_DOWNLOAD', 'Failed deleting pack downloads: $e');
      return false;
    } finally {
      _deleting = false;
    }
  }
}

/// Helper extension on PackModel to test whether all of its sessions are downloaded.
extension PackDownloadExtension on PackModel {
  bool get canDownloadAll =>
      items.isNotEmpty &&
      items.every((item) => item.type == TypeConstants.track);

  int downloadedTrackCount(List<Track> downloadedTracks) {
    final downloadedIds = downloadedTracks.map((track) => track.id).toSet();
    return items
        .where((item) => item.type == TypeConstants.track)
        .map((item) => item.id)
        .toSet()
        .intersection(downloadedIds)
        .length;
  }

  bool isFullyDownloaded(List<Track> downloadedTracks) {
    final trackItems = items
        .where((i) => i.type == TypeConstants.track)
        .toList();
    if (trackItems.isEmpty) return false;
    return trackItems.every(
      (item) => downloadedTracks.any((d) => d.id == item.id),
    );
  }
}
