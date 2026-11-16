import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/downloads/batch_download_provider.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/duration_preference_provider.dart';
import 'package:medito/providers/guide_name_preference_provider.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/meditation/download_track_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/download/audio_downloader_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/stats_provider.dart';
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
  ref.listen(
    audioDownloaderProvider.select(
      (state) => state.audioDownloadState.values.contains(
        AudioDownloadState.downloading,
      ),
    ),
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

  bool get _canRun =>
      !disposed &&
      ref.mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || disposed) return;
    if (ref.read(downloadSettingsProvider).downloadNext) {
      ref.invalidate(downloadNetworkProvider);
    }
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
    // Avoid changing the saved list underneath a manual/batch download.
    if (ref.read(batchDownloadProvider).isDownloading ||
        ref
            .read(audioDownloaderProvider)
            .audioDownloadState
            .values
            .contains(AudioDownloadState.downloading)) {
      return;
    }

    final settings = ref.read(downloadSettingsProvider);
    if (settings.deleteCompleted) await _deleteCompleted();
    if (!_canRun || !settings.downloadNext || !_networkAllowed()) return;

    final sessionId = ref.read(downloadNextSessionIdProvider);
    if (sessionId == null) return;
    final track = await ref.read(trackRepositoryProvider).fetchTrack(sessionId);
    if (!_canRun ||
        !_networkAllowed() ||
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
    if (await downloader.isFileDownloaded(fileName)) return;
    if (!_canRun || !_networkAllowed()) return;
    await ref
        .read(audioDownloaderProvider.notifier)
        .downloadTrackAudio(PlaybackRequest.fromTrack(track, voice, file));
  }

  bool _networkAllowed() {
    final settings = ref.read(downloadSettingsProvider);
    if (!settings.downloadNext) return false;
    final networks = ref.read(downloadNetworkProvider).value ?? const [];
    return networks.contains(ConnectivityResult.wifi) ||
        (settings.useMobileData &&
            networks.contains(ConnectivityResult.mobile));
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
