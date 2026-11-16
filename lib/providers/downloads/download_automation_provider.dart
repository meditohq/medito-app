import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/downloads/batch_download_provider.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/downloads/background_download_provider.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/meditation/download_track_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/download/audio_downloader_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/track_variant_selector.dart';
import 'package:medito/utils/utils.dart';

/// Follows the same course recommendation as Home, including its next-course
/// suggestion. Watching the suggested pack keeps late-loaded data reactive.
final downloadNextSessionIdProvider = Provider<String?>((ref) {
  final upNext = ref.watch(upNextProvider).value;
  if (upNext == null) return null;
  var session = upNext.nextSession;
  if (session == null && upNext.nextPackId != null) {
    final pack = ref.watch(packProvider(packId: upNext.nextPackId!)).value;
    session = pack?.items.where((item) => item.isCompleted != true).firstOrNull;
  }
  return session?.type == TypeConstants.track ? session!.id : null;
});

final downloadNetworkProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// Mounted once at the app root, so Downloads does not have to be open.
/// The two actions are independent; cleanup also works without a connection.
final downloadAutomationProvider = Provider<void>((ref) {
  // Restore completed native transfers even if the user has since disabled
  // automatic downloading, and cancel queued transfers when it is disabled.
  ref.watch(backgroundDownloadProvider);
  final settings = ref.watch(downloadSettingsProvider);
  if (!settings.deleteCompleted && !settings.downloadNext) return;

  final automation = _DownloadAutomation(ref);
  WidgetsBinding.instance.addObserver(automation);
  ref.onDispose(() {
    automation.disposed = true;
    WidgetsBinding.instance.removeObserver(automation);
  });

  void refresh<T>(T? previous, T next) => automation.request();
  ref.listen(statsProvider, refresh);
  ref.listen(downloadedTracksProvider, refresh);
  ref.listen(
    batchDownloadProvider.select((state) => state.isDownloading),
    refresh,
  );
  ref.listen(audioStateProvider.select((state) => state.isCompleted), refresh);

  if (settings.downloadNext) {
    ref.listen(downloadNetworkProvider, refresh);
    ref.listen(downloadNextSessionIdProvider, refresh);
    ref.listen(guideNamePreferenceProvider, refresh);
    ref.listen(durationPreferenceProvider, refresh);
  }
  scheduleMicrotask(automation.request);
});

class _DownloadAutomation with WidgetsBindingObserver {
  _DownloadAutomation(this.ref);

  final Ref ref;
  bool disposed = false;
  bool _running = false;
  bool _pending = false;

  bool get _canRun => !disposed && ref.mounted;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || disposed) return;
    if (ref.read(downloadSettingsProvider).downloadNext) {
      ref.invalidate(downloadNetworkProvider);
    }
    unawaited(
      ref.read(backgroundDownloadProvider).resume().catchError((Object error) {
        AppLogger.e(
          'BACKGROUND_DOWNLOAD',
          'Could not restore completed sessions',
          error,
        );
      }),
    );
    request();
  }

  void request() {
    if (!_canRun) return;
    _pending = true;
    if (_running) return;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_pending && _canRun) {
        _pending = false;
        try {
          await _reconcile();
        } catch (error) {
          // Keep existing downloads and retry on the next connection, resume
          // or Up Next change. No repeated retries on an unavailable server.
          AppLogger.e('AUTO_DOWNLOAD', 'Could not update downloads', error);
          _pending = false;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcile() async {
    final queue = ref.read(backgroundDownloadProvider);
    await queue.ready;
    if (!_canRun) return;
    // Avoid changing the saved list underneath a manual/batch download.
    if (ref.read(batchDownloadProvider).isDownloading ||
        ref
            .read(audioDownloaderProvider)
            .audioDownloadState
            .entries
            .any(
              (entry) =>
                  entry.value == AudioDownloadState.downloading &&
                  !queue.owns(entry.key),
            )) {
      return;
    }

    final settings = ref.read(downloadSettingsProvider);
    if (settings.deleteCompleted) await _deleteCompleted();
    if (!_canRun || !settings.downloadNext) return;

    final sessionId = ref.read(downloadNextSessionIdProvider);
    await queue.cancelExcept(sessionId);
    if (!_canRun) return;
    if (sessionId == null) return;
    final track = await _loadTrack(sessionId);
    if (!_canRun ||
        track == null ||
        track.voices.isEmpty ||
        track.voices.any((voice) => voice.audioFiles.isEmpty) ||
        ref.read(downloadNextSessionIdProvider) != sessionId) {
      return;
    }
    final (:voice, :file) = TrackVariantSelector.resolve(
      track,
      guideName: ref.read(guideNamePreferenceProvider),
      durationMs: ref.read(durationPreferenceProvider),
    );
    final fileName =
        '${track.id}-${file.id}${getAudioFileExtension(file.path)}';
    final downloader = ref.read(downloaderRepositoryProvider);
    final request = PlaybackRequest.fromTrack(track, voice, file);
    await queue.cancelExcept(sessionId, fileId: file.id);
    if (!_canRun) return;
    if (await downloader.isFileDownloaded(fileName)) {
      final saved = await ref
          .read(trackRepositoryProvider)
          .fetchTrackFromPreference();
      if (_canRun &&
          !saved.any(
            (track) => track.voices.any(
              (voice) => voice.audioFiles.any((audio) => audio.id == file.id),
            ),
          )) {
        await ref
            .read(audioDownloaderProvider.notifier)
            .saveDownloadedRequest(request);
      }
    } else {
      await queue.enqueue(request, requiresWiFi: !settings.useMobileData);
    }
    if (!_canRun) return;
    // Cache just the following session's metadata, not its audio, so an
    // offline completion can queue it to wait for Wi-Fi while the app closes.
    final items = ref.read(upNextProvider).value?.pack.items ?? const [];
    final index = items.indexWhere((item) => item.id == sessionId);
    if (index >= 0 && _hasConnection) {
      final following = items
          .skip(index + 1)
          .where(
            (item) =>
                item.type == TypeConstants.track && item.isCompleted != true,
          )
          .firstOrNull;
      if (following != null) {
        try {
          await _loadTrack(following.id);
        } catch (error) {
          AppLogger.d(
            'AUTO_DOWNLOAD',
            'Next session metadata will be retried later: $error',
          );
        }
      }
    }
  }

  bool get _hasConnection {
    final networks = ref.read(downloadNetworkProvider).value ?? const [];
    return networks.any((result) => result != ConnectivityResult.none);
  }

  Future<Track?> _loadTrack(String id) async {
    final prefs = ref.read(sharedPreferencesProvider);
    Map<String, dynamic> cache;
    try {
      cache = jsonDecode(
        prefs.getString(SharedPreferenceConstants.autoDownloadTrackCache) ??
            '{}',
      ) as Map<String, dynamic>;
      if (cache[id] is Map<String, dynamic>) {
        return Track.fromJson(cache[id] as Map<String, dynamic>);
      }
    } catch (_) {
      cache = {};
    }
    if (!_hasConnection) return null;
    final track = await ref.read(trackRepositoryProvider).fetchTrack(id);
    if (!_canRun) return null;
    cache[id] = track.toJson();
    while (cache.length > 2) {
      cache.remove(cache.keys.first);
    }
    await prefs.setString(
      SharedPreferenceConstants.autoDownloadTrackCache,
      jsonEncode(cache),
    );
    return track;
  }

  Future<void> _deleteCompleted() async {
    final stats = ref.read(statsProvider).value;
    if (stats == null) return;
    final completedTracks = (stats.tracksChecked ?? const <String>[]).toSet();
    final completedFiles =
        stats.audioCompleted?.map((entry) => entry.id).toSet() ?? <String>{};
    if (completedTracks.isEmpty && completedFiles.isEmpty) return;
    final tracks = await ref
        .read(trackRepositoryProvider)
        .fetchTrackFromPreference();
    if (!_canRun) return;
    final audio = ref.read(audioDownloaderProvider.notifier);
    for (final track in tracks) {
      // Preserve every saved variant of an active/paused session. Replays
      // can already be marked complete in the user's history.
      final current = ref.read(playerProvider);
      if (current?.trackId == track.id &&
          !ref.read(audioStateProvider).isCompleted) {
        continue;
      }
      for (final voice in track.voices) {
        for (final file in voice.audioFiles) {
          if (!_canRun) return;
          if (!completedTracks.contains(track.id) &&
              !completedFiles.contains(file.id)) {
            continue;
          }
          await audio.removeTrackDownload(
            fileName:
                '${track.id}-${file.id}${getAudioFileExtension(file.path)}',
            fileId: file.id,
          );
        }
      }
    }
  }
}
