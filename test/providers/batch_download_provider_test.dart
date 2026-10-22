import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

class FakeTrackRepository implements TrackRepository {
  final Map<String, Track> tracksById = {};
  List<Track> downloadedTracks = [];
  Duration writeDelay = Duration.zero;
  final savedSnapshots = <List<Track>>[];

  @override
  Future<Track> fetchTrack(String trackId) async {
    final track = tracksById[trackId];
    if (track != null) return track;
    throw Exception('Track not found');
  }

  @override
  Future<List<Track>> fetchTrackFromPreference() async {
    return List<Track>.from(downloadedTracks);
  }

  @override
  Future<void> addTrackInPreference(List<Track> trackList) async {
    if (writeDelay != Duration.zero) await Future<void>.delayed(writeDelay);
    downloadedTracks = List<Track>.from(trackList);
    savedSnapshots.add(List<Track>.from(trackList));
  }

  @override
  Future<void> addCurrentlyPlayingTrackInPreference(Track track) async {}

  @override
  Future<Track?> fetchCurrentlyPlayingTrackFromPreference() async => null;

  @override
  Future<void> removeCurrentlyPlayingTrackInPreference() async {}
}

class FakeDownloaderRepository implements DownloaderRepository {
  final Set<String> files = {};

  @override
  Future<void> deleteDownloadedFile(String fileName) async {
    files.remove(fileName);
  }

  @override
  Future<void> downloadFile(
    String url, {
    required String fileName,
    void Function(int, int)? onReceiveProgress,
  }) async {
    files.add(fileName);
  }

  @override
  Future<String?> getDownloadedFile(String fileName) async {
    return files.contains(fileName) ? '/fake/$fileName' : null;
  }

  @override
  Future<bool> isFileDownloaded(String name) async {
    return files.contains(name);
  }
}

class ControlledDownloaderRepository extends FakeDownloaderRepository {
  final pending = <String, Completer<void>>{};
  final calls = <String>[];

  @override
  Future<void> downloadFile(
    String url, {
    required String fileName,
    void Function(int, int)? onReceiveProgress,
  }) async {
    calls.add(fileName);
    final completion = Completer<void>();
    pending[fileName] = completion;
    await completion.future;
    files.add(fileName);
  }

  void finish(String fileName) => pending.remove(fileName)!.complete();
  void fail(String fileName) =>
      pending.remove(fileName)!.completeError(Exception('Network lost'));
}

Future<void> waitUntil(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for download state');
}

class FakeAnalyticsService implements FirebaseAnalyticsService {
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeTrackRepository trackRepo;
  late FakeDownloaderRepository downloaderRepo;
  late FakeAnalyticsService analyticsService;
  late ProviderContainer container;

  final testTrack1 = Track(
    id: 't1',
    title: 'Track 1',
    description: 'Desc 1',
    coverUrl: 'https://example.com/c1.jpg',
    isPublished: true,
    hasBackgroundSound: false,
    voices: [
      const TrackVoice(
        guideName: 'Will',
        audioFiles: [
          TrackAudioFile(
            id: 'f1',
            path: 'https://example.com/f1.mp3',
            duration: 600,
          ),
        ],
      ),
    ],
  );

  final testTrack2 = Track(
    id: 't2',
    title: 'Track 2',
    description: 'Desc 2',
    coverUrl: 'https://example.com/c2.jpg',
    isPublished: true,
    hasBackgroundSound: false,
    voices: [
      const TrackVoice(
        guideName: 'Will',
        audioFiles: [
          TrackAudioFile(
            id: 'f2',
            path: 'https://example.com/f2.mp3',
            duration: 600,
          ),
        ],
      ),
    ],
  );

  final testPack = const PackModel(
    id: 'pack1',
    title: 'Test Course',
    items: [
      PackItemsModel(
        type: TypeConstants.track,
        id: 't1',
        title: 'Track 1',
        path: '/t1',
      ),
      PackItemsModel(
        type: TypeConstants.track,
        id: 't2',
        title: 'Track 2',
        path: '/t2',
      ),
    ],
  );

  setUp(() {
    trackRepo = FakeTrackRepository();
    trackRepo.tracksById['t1'] = testTrack1;
    trackRepo.tracksById['t2'] = testTrack2;

    downloaderRepo = FakeDownloaderRepository();
    analyticsService = FakeAnalyticsService();

    container = ProviderContainer(
      overrides: [
        trackRepositoryProvider.overrideWithValue(trackRepo),
        downloaderRepositoryProvider.overrideWithValue(downloaderRepo),
        analyticsServiceProvider.overrideWithValue(analyticsService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('isFullyDownloaded returns true only when all items are downloaded', () {
    expect(testPack.isFullyDownloaded([]), isFalse);
    expect(testPack.isFullyDownloaded([testTrack1]), isFalse);
    expect(testPack.isFullyDownloaded([testTrack1, testTrack2]), isTrue);
  });

  test(
    'bulk downloads require a nonempty pack containing only tracks',
    () async {
      final folders = testPack.copyWith(
        items: [testPack.items.first.copyWith(type: TypeConstants.pack)],
      );
      final mixed = testPack.copyWith(
        items: [
          ...testPack.items,
          testPack.items.first.copyWith(type: TypeConstants.link),
        ],
      );
      expect(testPack.canDownloadAll, isTrue);
      for (final pack in [folders, mixed, testPack.copyWith(items: [])]) {
        expect(pack.canDownloadAll, isFalse);
        await container
            .read(batchDownloadProvider.notifier)
            .startPackDownload(pack);
        expect(
          container.read(batchDownloadProvider).status,
          BatchDownloadStatus.idle,
        );
      }
      expect(downloaderRepo.files, isEmpty);
      expect(analyticsService.loggedEvents, isEmpty);
    },
  );

  test('download count ignores duplicates and tracks outside this pack', () {
    expect(testPack.downloadedTrackCount([]), 0);
    expect(testPack.downloadedTrackCount([testTrack1, testTrack1]), 1);
    expect(
      testPack.downloadedTrackCount([
        testTrack1,
        testTrack2,
        testTrack1.copyWith(id: 'other'),
      ]),
      2,
    );
  });

  test(
    'startPackDownload downloads all sessions and updates preferences',
    () async {
      final notifier = container.read(batchDownloadProvider.notifier);

      expect(
        container.read(batchDownloadProvider).status,
        BatchDownloadStatus.idle,
      );

      await notifier.startPackDownload(testPack);

      final finalState = container.read(batchDownloadProvider);
      expect(finalState.status, BatchDownloadStatus.completed);
      expect(finalState.completed, 2);
      expect(finalState.total, 2);

      expect(downloaderRepo.files.contains('t1-f1.mp3'), isTrue);
      expect(downloaderRepo.files.contains('t2-f2.mp3'), isTrue);

      final savedTracks = await trackRepo.fetchTrackFromPreference();
      expect(savedTracks.length, 2);
      expect(savedTracks.any((t) => t.id == 't1'), isTrue);
      expect(savedTracks.any((t) => t.id == 't2'), isTrue);
    },
  );

  ProviderContainer controlledContainer(ControlledDownloaderRepository files) =>
      ProviderContainer(
        overrides: [
          trackRepositoryProvider.overrideWithValue(trackRepo),
          downloaderRepositoryProvider.overrideWithValue(files),
          analyticsServiceProvider.overrideWithValue(analyticsService),
        ],
      );

  test(
    'completed tracks are saved before the batch finishes and survive restart',
    () async {
      final files = ControlledDownloaderRepository();
      final first = controlledContainer(files);
      final batch = first
          .read(batchDownloadProvider.notifier)
          .startPackDownload(testPack);
      await waitUntil(() => files.pending.length == 2);
      files.finish('t1-f1.mp3');
      await waitUntil(() => trackRepo.downloadedTracks.length == 1);
      expect(
        first.read(batchDownloadProvider).status,
        BatchDownloadStatus.downloading,
      );
      expect(trackRepo.downloadedTracks.single.id, 't1');
      first.dispose();
      // Finishing the old fake network request after disposal must not mark it saved.
      files.finish('t2-f2.mp3');
      await batch;
      files.files.remove('t2-f2.mp3');
      final restarted = controlledContainer(files);
      addTearDown(restarted.dispose);
      final saved = await restarted.read(downloadedTracksProvider.future);
      expect(testPack.downloadedTrackCount(saved), 1);
      final retry = restarted
          .read(batchDownloadProvider.notifier)
          .startPackDownload(testPack);
      await waitUntil(() => files.pending.containsKey('t2-f2.mp3'));
      expect(files.calls.where((name) => name == 't1-f1.mp3').length, 1);
      files.finish('t2-f2.mp3');
      await retry;
      expect(trackRepo.downloadedTracks.map((track) => track.id).toSet(), {
        't1',
        't2',
      });
    },
  );

  test('concurrent completions do not overwrite saved tracks', () async {
    trackRepo.writeDelay = const Duration(milliseconds: 10);
    final files = ControlledDownloaderRepository();
    final active = controlledContainer(files);
    addTearDown(active.dispose);
    final batch = active
        .read(batchDownloadProvider.notifier)
        .startPackDownload(testPack);
    await waitUntil(() => files.pending.length == 2);
    files.finish('t1-f1.mp3');
    files.finish('t2-f2.mp3');
    await batch;
    expect(trackRepo.savedSnapshots.first.length, 1);
    expect(trackRepo.downloadedTracks.map((track) => track.id).toSet(), {
      't1',
      't2',
    });
  });

  test(
    'network failure retains completed tracks without saving failed tracks',
    () async {
      final files = ControlledDownloaderRepository();
      final active = controlledContainer(files);
      addTearDown(active.dispose);
      final batch = active
          .read(batchDownloadProvider.notifier)
          .startPackDownload(testPack);
      await waitUntil(() => files.pending.length == 2);
      files.finish('t1-f1.mp3');
      files.fail('t2-f2.mp3');
      await batch;
      expect(
        active.read(batchDownloadProvider).status,
        BatchDownloadStatus.error,
      );
      expect(trackRepo.downloadedTracks.map((track) => track.id), ['t1']);
    },
  );

  test('cancellation retains downloads that finish in flight', () async {
    final files = ControlledDownloaderRepository();
    final active = controlledContainer(files);
    addTearDown(active.dispose);
    final notifier = active.read(batchDownloadProvider.notifier);
    final batch = notifier.startPackDownload(testPack);
    await waitUntil(() => files.pending.length == 2);
    await notifier.cancelDownload();
    files.finish('t1-f1.mp3');
    files.finish('t2-f2.mp3');
    await batch;
    expect(active.read(batchDownloadProvider).status, BatchDownloadStatus.idle);
    expect(trackRepo.downloadedTracks.length, 2);
  });

  test('existing files are registered without downloading again', () async {
    downloaderRepo.files.addAll(['t1-f1.mp3', 't2-f2.mp3']);
    await container
        .read(batchDownloadProvider.notifier)
        .startPackDownload(testPack);
    expect(trackRepo.downloadedTracks.length, 2);
    expect(
      container.read(batchDownloadProvider).status,
      BatchDownloadStatus.completed,
    );
  });

  test('cancelDownload stops batch and resets to idle', () async {
    final notifier = container.read(batchDownloadProvider.notifier);
    await notifier.cancelDownload();
    expect(
      container.read(batchDownloadProvider).status,
      BatchDownloadStatus.idle,
    );
  });

  test(
    'deletePackDownloads deletes files and removes from preferences',
    () async {
      final notifier = container.read(batchDownloadProvider.notifier);

      // Download first
      await notifier.startPackDownload(testPack);
      expect(downloaderRepo.files.length, 2);
      expect(trackRepo.downloadedTracks.length, 2);

      // Now delete
      await notifier.deletePackDownloads(testPack);

      expect(downloaderRepo.files.isEmpty, isTrue);
      expect(trackRepo.downloadedTracks.isEmpty, isTrue);
    },
  );
}
