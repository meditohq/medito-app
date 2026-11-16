import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/providers/player/download/audio_downloader_provider.dart';
import 'package:medito/repositories/downloader/download_library.dart';
import 'package:medito/repositories/track/track_repository.dart';

import 'batch_download_provider_test.dart' show FakeTrackRepository;

PlaybackRequest _request(String id) => PlaybackRequest(
  trackId: id,
  fileId: '$id-file',
  title: id,
  description: '',
  coverUrl: '',
  remoteUrl: 'https://example.test/$id.mp3',
  duration: 600000,
  hasBackgroundSound: false,
);

void main() {
  test(
    'simultaneous native and manual completions retain both downloads',
    () async {
      final repository = FakeTrackRepository()
        ..writeDelay = const Duration(milliseconds: 10);
      final container = ProviderContainer(
        overrides: [trackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final audio = container.read(audioDownloaderProvider.notifier);
      await Future.wait([
        audio.saveDownloadedRequest(_request('native')),
        audio.saveDownloadedRequest(_request('manual')),
      ]);
      expect(repository.downloadedTracks.map((track) => track.id), [
        'native',
        'manual',
      ]);
    },
  );

  test(
    'a native completion and batch update retain each other\'s entries',
    () async {
      final repository = FakeTrackRepository()
        ..writeDelay = const Duration(milliseconds: 10);
      final container = ProviderContainer(
        overrides: [trackRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final audio = container.read(audioDownloaderProvider.notifier);
      await audio.saveDownloadedRequest(_request('batch'));
      final batchTrack = repository.downloadedTracks.single;
      repository.downloadedTracks.clear();
      await Future.wait([
        audio.saveDownloadedRequest(_request('native')),
        container
            .read(downloadLibraryProvider)
            .update((tracks) => [...tracks, batchTrack]),
      ]);
      expect(repository.downloadedTracks.map((track) => track.id), [
        'native',
        'batch',
      ]);
    },
  );
}
