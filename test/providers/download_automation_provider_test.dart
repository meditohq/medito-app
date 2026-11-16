import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/downloads/download_automation_provider.dart';
import 'package:medito/providers/downloads/background_download_provider.dart';
import 'package:medito/providers/player/download/audio_downloader_provider.dart';
import 'package:medito/services/downloads/background_download_service.dart';
import 'package:medito/providers/downloads/download_settings_provider.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/views/previews/preview_support.dart';

import 'batch_download_provider_test.dart'
    show FakeTrackRepository, FakeDownloaderRepository;

Track _track(String id) => Track(
  id: id,
  title: 'Session $id',
  description: '',
  coverUrl: '',
  isPublished: true,
  hasBackgroundSound: false,
  voices: [
    for (final guide in ['Will', 'Steven'])
      TrackVoice(
        guideName: guide,
        audioFiles: [
          for (final minutes in [5, 10])
            TrackAudioFile(
              id: '$id-$guide-$minutes',
              path: 'https://example.test/$id-$guide-$minutes.mp3',
              duration: minutes * 60000,
            ),
        ],
      ),
  ],
);

UpNextData _upNext(String? id, {String? nextPackId}) => UpNextData(
  pack: const PackModel(id: 'course', title: 'Course'),
  nextSession: id == null
      ? null
      : PackItemsModel(
          id: id,
          title: 'Session $id',
          type: TypeConstants.track,
          path: '/tracks/$id',
        ),
  completedCount: id == null ? 1 : 0,
  totalCount: 1,
  nextPackId: nextPackId,
);

class _Recommendation extends Notifier<UpNextData> {
  @override
  UpNextData build() => _upNext('a');
  void set(UpNextData value) => state = value;
}

final _recommendationProvider = NotifierProvider<_Recommendation, UpNextData>(
  _Recommendation.new,
);

class _Stats extends StatsNotifier {
  _Stats(this.initial);
  final LocalAllStats initial;
  @override
  Future<LocalAllStats> build() async => initial;
  void complete(String id) => state = AsyncData(
    state.requireValue.copyWith(
      tracksChecked: [...?state.value?.tracksChecked, id],
    ),
  );
}

class _Files extends FakeDownloaderRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<void> downloadFile(
    String url, {
    required String fileName,
    void Function(int, int)? onReceiveProgress,
  }) async {
    calls++;
    if (fail) throw StateError('Offline');
    await super.downloadFile(url, fileName: fileName);
  }
}

class _NativeQueue implements AutomaticDownloadQueue {
  _NativeQueue(this.download, {required this.enabled});
  final Future<void> Function(PlaybackRequest) download;
  bool enabled;
  bool requiresWiFi = true;
  List<ConnectivityResult> network = [];
  final pending = <String, PlaybackRequest>{};
  final knownFiles = <String>{};
  final inFlight = <String>{};
  int enqueues = 0;
  @override
  Future<void> get ready => Future.value();
  @override
  bool owns(String fileName) => knownFiles.contains(fileName);
  @override
  Future<void> enqueue(
    PlaybackRequest request, {
    required bool requiresWiFi,
  }) async {
    if (!enabled || pending.containsKey(request.fileId)) return;
    enqueues++;
    this.requiresWiFi = requiresWiFi;
    pending[request.fileId] = request;
    knownFiles.add(BackgroundDownloadService.fileName(request));
    await _completeIfAllowed();
  }

  Future<void> connect(List<ConnectivityResult> value) async {
    network = value;
    await _completeIfAllowed();
  }

  Future<void> _completeIfAllowed() async {
    if (!network.contains(ConnectivityResult.wifi) &&
        (requiresWiFi || !network.contains(ConnectivityResult.mobile))) {
      return;
    }
    for (final request in pending.values.toList()) {
      if (!inFlight.add(request.fileId)) continue;
      try {
        await download(request);
      } finally {
        pending.remove(request.fileId);
        inFlight.remove(request.fileId);
      }
    }
  }

  @override
  Future<void> configure({
    required bool enabled,
    required bool requiresWiFi,
  }) async {
    this.enabled = enabled;
    this.requiresWiFi = requiresWiFi;
    if (!enabled) pending.clear();
  }

  @override
  Future<void> cancelExcept(String? trackId, {String? fileId}) async {
    pending.removeWhere(
      (_, request) =>
          request.trackId != trackId ||
          (fileId != null && request.fileId != fileId),
    );
  }

  @override
  Future<void> resume() async {}
  @override
  void dispose() {}
}

Future<void> _drain() async {
  // Lets stream events, Riverpod invalidations and serialized IO finish.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late FakeTrackRepository tracks;
  late _Files files;
  late _Stats stats;
  late StreamController<List<ConnectivityResult>> network;
  late _NativeQueue queue;

  Future<void> start({
    bool download = true,
    bool cleanup = false,
    bool mobile = false,
    List<String> completed = const [],
  }) async {
    tracks = FakeTrackRepository();
    tracks.tracksById.addAll({
      for (final id in ['a', 'b', 'c']) id: _track(id),
    });
    files = _Files();
    stats = _Stats(LocalAllStats.empty().copyWith(tracksChecked: completed));
    network = StreamController<List<ConnectivityResult>>.broadcast();
    queue = _NativeQueue(
      (request) => container
          .read(audioDownloaderProvider.notifier)
          .downloadTrackAudio(request),
      enabled: download,
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          MemoryPrefs({
            SharedPreferenceConstants.autoDownloadNextSession: download,
            SharedPreferenceConstants.autoDeleteCompletedDownloads: cleanup,
            SharedPreferenceConstants.autoDownloadOnMobileData: mobile,
            SharedPreferenceConstants.lastSelectedGuideName: 'Steven',
            'meditation_duration_preference': 600000,
          }),
        ),
        trackRepositoryProvider.overrideWithValue(tracks),
        downloaderRepositoryProvider.overrideWithValue(files),
        backgroundDownloadProvider.overrideWithValue(queue),
        statsProvider.overrideWith(() => stats),
        audioStateProvider.overrideWith(AudioStateNotifier.new),
        upNextProvider.overrideWith(
          (ref) => AsyncData(ref.watch(_recommendationProvider)),
        ),
        downloadNetworkProvider.overrideWith((ref) => network.stream),
        packTrackIdsProvider.overrideWith((ref) async => {}),
        packDataProvider(packId: 'next').overrideWith(
          (ref) async => PackModel(
            id: 'next',
            title: 'Next course',
            items: [
              for (final id in ['b', 'c'])
                PackItemsModel(
                  id: id,
                  title: id,
                  type: TypeConstants.track,
                  path: '/tracks/$id',
                ),
            ],
          ),
        ),
      ],
    );
    final nativeSubscription = network.stream.listen((value) {
      unawaited(queue.connect(value));
    });
    container.listen(downloadSettingsProvider, (previous, next) {
      unawaited(
        queue.configure(
          enabled: next.downloadNext,
          requiresWiFi: !next.useMobileData,
        ),
      );
    });
    container.listen(downloadAutomationProvider, (_, _) {});
    await _drain();
    addTearDown(() async {
      container.dispose();
      await nativeSubscription.cancel();
      await network.close();
    });
  }

  test('both switches off performs no download or deletion', () async {
    await start(download: false);
    tracks.downloadedTracks = [_track('a')];
    network.add([ConnectivityResult.wifi]);
    await _drain();
    expect(files.calls, 0);
    expect(tracks.downloadedTracks.map((t) => t.id), ['a']);
  });

  test(
    'downloads the Home recommendation using the saved voice and length',
    () async {
      await start();
      network.add([ConnectivityResult.wifi]);
      await _drain();
      expect(files.files, {'a-a-Steven-10.mp3'});
      expect(tracks.downloadedTracks.single.voices.single.guideName, 'Steven');
      expect(
        tracks.downloadedTracks.single.voices.single.audioFiles.single.duration,
        600000,
      );
      network.add([ConnectivityResult.wifi]);
      await _drain();
      expect(files.calls, 1);
    },
  );

  test('waits offline and on mobile data until Wi-Fi returns', () async {
    await start();
    network.add([ConnectivityResult.none]);
    await _drain();
    network.add([ConnectivityResult.mobile]);
    await _drain();
    expect(files.calls, 0);
    network.add([ConnectivityResult.wifi]);
    await _drain();
    expect(files.calls, 1);
  });

  test('mobile data requires explicit opt-in', () async {
    await start(mobile: true);
    network.add([ConnectivityResult.mobile]);
    await _drain();
    expect(files.calls, 1);
  });

  test(
    'completion prepares the next session and keeps downloads with cleanup off',
    () async {
      await start();
      network.add([ConnectivityResult.wifi]);
      await _drain();
      stats.complete('a');
      container.read(_recommendationProvider.notifier).set(_upNext('b'));
      await _drain();
      expect(tracks.downloadedTracks.map((t) => t.id), ['a', 'b']);
    },
  );

  test(
    'cleanup alone removes completed manual downloads while offline',
    () async {
      await start(download: false, cleanup: true, completed: ['a']);
      tracks.downloadedTracks = [_track('a'), _track('b')];
      // A stats update retries cleanup after the fixture was saved.
      stats.complete('a');
      await _drain();
      expect(tracks.downloadedTracks.map((t) => t.id), ['b']);
      expect(files.calls, 0);
    },
  );

  test('cleanup preserves a paused replay until playback completes', () async {
    await start(download: false, cleanup: true);
    final track = _track('a');
    tracks.downloadedTracks = [track];
    container
        .read(playerProvider.notifier)
        .prepare(
          PlaybackRequest.fromTrack(
            track,
            track.voices.first,
            track.voices.first.audioFiles.first,
          ),
        );
    stats.complete('a');
    await _drain();
    expect(tracks.downloadedTracks.map((t) => t.id), ['a']);
    container
        .read(audioStateProvider.notifier)
        .updatePlaybackState(
          container.read(audioStateProvider).copyWith(isCompleted: true),
        );
    await _drain();
    expect(tracks.downloadedTracks, isEmpty);
  });

  test(
    'failed download keeps existing sessions and retries after reconnecting',
    () async {
      await start();
      tracks.downloadedTracks = [_track('b')];
      files.fail = true;
      network.add([ConnectivityResult.wifi]);
      await _drain();
      expect(tracks.downloadedTracks.map((t) => t.id), ['b']);
      expect(files.calls, 1);
      files.fail = false;
      network.add([ConnectivityResult.none]);
      await _drain();
      network.add([ConnectivityResult.wifi]);
      await _drain();
      expect(tracks.downloadedTracks.map((t) => t.id), ['b', 'a']);
    },
  );

  test('a completed course downloads the first unfinished session of the suggested course', () async {
    await start(completed: ['b']);
    container
        .read(_recommendationProvider.notifier)
        .set(_upNext(null, nextPackId: 'next'));
    network.add([ConnectivityResult.wifi]);
    await _drain();
    expect(tracks.downloadedTracks.map((t) => t.id), ['c']);
  });

  test('both enabled remove the finished download and prepare the following session', () async {
    await start(cleanup: true);
    network.add([ConnectivityResult.wifi]);
    await _drain();
    stats.complete('a');
    container.read(_recommendationProvider.notifier).set(_upNext('b'));
    await _drain();
    expect(tracks.downloadedTracks.map((t) => t.id), ['b']);
    expect(files.files, {'b-b-Steven-10.mp3'});
  });

  test(
    'turning automatic downloading off keeps already saved sessions',
    () async {
      await start();
      network.add([ConnectivityResult.wifi]);
      await _drain();
      await container
          .read(downloadSettingsProvider.notifier)
          .setDownloadNext(false);
      container.read(_recommendationProvider.notifier).set(_upNext('b'));
      network.add([ConnectivityResult.wifi]);
      await _drain();
      expect(tracks.downloadedTracks.map((t) => t.id), ['a']);
      expect(files.calls, 1);
    },
  );

  test('Wi-Fi-only audio queues on mobile data and finishes without a foreground reconciliation', () async {
    await start();
    network.add([ConnectivityResult.mobile]);
    await _drain();
    expect(queue.pending.values.single.trackId, 'a');
    expect(files.calls, 0);
    await queue.connect([ConnectivityResult.wifi]);
    await _drain();
    expect(tracks.downloadedTracks.map((t) => t.id), ['a']);
  });

  test(
    'an offline completion uses cached metadata to queue the next session',
    () async {
      await start();
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setString(
        SharedPreferenceConstants.autoDownloadTrackCache,
        jsonEncode({'b': _track('b').toJson()}),
      );
      network.add([ConnectivityResult.none]);
      container.read(_recommendationProvider.notifier).set(_upNext('b'));
      await _drain();
      expect(queue.pending.values.single.trackId, 'b');
      expect(files.calls, 0);
    },
  );
}
