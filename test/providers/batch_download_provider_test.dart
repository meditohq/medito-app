import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/downloads/batch_download_service.dart';

class FakeTrackRepository implements TrackRepository {
  final Map<String, Track> tracksById = {};
  List<Track> downloadedTracks = [];

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
    downloadedTracks = List<Track>.from(trackList);
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

class FakeBatchDownloadService extends BatchDownloadService {
  final FakeDownloaderRepository downloader;
  bool isBatchRunning = false;

  FakeBatchDownloadService(this.downloader);

  @override
  Future<void> downloadBatch(
    List<BatchDownloadItem> items, {
    void Function(BatchDownloadProgress progress)? onProgress,
  }) async {
    isBatchRunning = true;
    var completed = 0;
    for (final item in items) {
      if (!isBatchRunning) break;
      await downloader.downloadFile(item.url, fileName: item.fileName);
      completed++;
      onProgress?.call(
        BatchDownloadProgress(
          completed: completed,
          total: items.length,
          isRunning: true,
        ),
      );
    }
    isBatchRunning = false;
  }

  @override
  Future<void> stopBatch() async {
    isBatchRunning = false;
  }
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
  late FakeBatchDownloadService batchService;
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
    batchService = FakeBatchDownloadService(downloaderRepo);
    analyticsService = FakeAnalyticsService();

    container = ProviderContainer(
      overrides: [
        trackRepositoryProvider.overrideWithValue(trackRepo),
        downloaderRepositoryProvider.overrideWithValue(downloaderRepo),
        batchDownloadServiceProvider.overrideWithValue(batchService),
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

  test('startPackDownload downloads all sessions and updates preferences',
      () async {
    final notifier = container.read(batchDownloadProvider.notifier);

    expect(container.read(batchDownloadProvider).status,
        BatchDownloadStatus.idle);

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
  });

  test('deletePackDownloads deletes files and removes from preferences',
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
  });
}
