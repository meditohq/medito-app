import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/audio_download_widget.dart';
import '../providers/batch_download_provider_test.dart'
    show FakeTrackRepository, FakeDownloaderRepository;

class _SlowTrackRepository extends FakeTrackRepository {
  @override
  Future<void> addTrackInPreference(List<Track> trackList) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await super.addTrackInPreference(trackList);
  }
}

const _request = PlaybackRequest(
  trackId: 'one',
  fileId: 'file-one',
  title: 'First track',
  description: '',
  coverUrl: '',
  remoteUrl: 'https://example.test/one.mp3',
  duration: 600,
  hasBackgroundSound: false,
);

Track _track(String id) => Track(
  id: id,
  title: id,
  description: '',
  coverUrl: '',
  isPublished: true,
  hasBackgroundSound: false,
  voices: [
    TrackVoice(
      guideName: 'Will',
      audioFiles: [
        TrackAudioFile(
          id: 'file-$id',
          path: 'https://example.test/$id.mp3',
          duration: 600,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets(
    'player deletion refreshes the pack marker and supports repeated download/delete',
    (tester) async {
      final tracks = _SlowTrackRepository()
        ..downloadedTracks = [_track('one'), _track('two')];
      final files = FakeDownloaderRepository()
        ..files.addAll(['one-file-one.mp3', 'two-file-two.mp3']);
      final container = ProviderContainer(
        overrides: [
          trackRepositoryProvider.overrideWithValue(tracks),
          downloaderRepositoryProvider.overrideWithValue(files),
        ],
      );
      addTearDown(container.dispose);
      final downloader = container.read(audioDownloaderProvider.notifier);
      await downloader.getTrackPath('one-file-one.mp3');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Column(
                children: [
                  PackItemWidget(
                    item: PackItemsModel(
                      id: 'one',
                      type: 'track',
                      title: 'First track',
                      path: '/one',
                      subtitle: '10 minutes',
                    ),
                  ),
                  AudioDownloadWidget(request: _request),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Downloaded'), findsOneWidget);
      expect(find.text('Downloaded'), findsNothing);
      expect(find.byIcon(Icons.download_done), findsOneWidget);

      Future<void> deleteFromPlayer() async {
        await tester.tap(find.byTooltip('Delete download'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Downloaded'), findsNothing);
        expect(find.byTooltip('Download audio'), findsOneWidget);
        expect(files.files, {'two-file-two.mp3'});
        expect(tracks.downloadedTracks.map((track) => track.id), ['two']);
        expect(
          (await container.read(
            downloadedTracksProvider.future,
          )).map((track) => track.id),
          ['two'],
        );
      }

      await deleteFromPlayer();

      // Re-saving the same file must not reuse an earlier deletion's result.
      final download = downloader.downloadTrackAudio(_request);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await download;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Downloaded'), findsOneWidget);
      await deleteFromPlayer();
    },
  );
}
