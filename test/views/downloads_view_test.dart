import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/downloads/downloads_view.dart';

Track _track(String id) => Track(
  id: id,
  title: 'Track $id',
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
          duration: 600000,
        ),
      ],
    ),
  ],
);

class _FakeTrackRepository implements TrackRepository {
  _FakeTrackRepository(this.saved);

  List<Track> saved;

  @override
  Future<List<Track>> fetchTrackFromPreference() async => [...saved];

  @override
  Future<void> addTrackInPreference(List<Track> trackList) async =>
      saved = [...trackList];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloaderRepository implements DownloaderRepository {
  final deleted = <String>[];

  @override
  Future<bool> isFileDownloaded(String name) async => true;

  @override
  Future<void> deleteDownloadedFile(String fileName) async =>
      deleted.add(fileName);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Covers show an endless loading shimmer in tests, so pumpAndSettle never
// settles; step past the dismiss/resize animations instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _FakeTrackRepository tracks;
  late _FakeDownloaderRepository files;

  Future<void> pumpDownloads(WidgetTester tester) async {
    tracks = _FakeTrackRepository([_track('a'), _track('b')]);
    files = _FakeDownloaderRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackRepositoryProvider.overrideWithValue(tracks),
          downloaderRepositoryProvider.overrideWithValue(files),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const DownloadsView(isRoot: true),
        ),
      ),
    );
    await _settle(tester);
  }

  Future<void> swipeAway(WidgetTester tester, String title) async {
    await tester.drag(find.text(title), const Offset(-600, 0));
    await _settle(tester);
  }

  testWidgets('swipe hides the row and Undo brings it back untouched', (
    tester,
  ) async {
    await pumpDownloads(tester);
    await swipeAway(tester, 'Track a');

    expect(find.text('Track a'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    expect(find.text('Track a'), findsOneWidget);
    // Past the undo window nothing is deleted.
    await tester.pump(const Duration(seconds: 5));
    expect(files.deleted, isEmpty);
    expect(tracks.saved.map((t) => t.id), ['a', 'b']);
  });

  testWidgets('without Undo the download is deleted after the window', (
    tester,
  ) async {
    await pumpDownloads(tester);
    await swipeAway(tester, 'Track a');

    expect(files.deleted, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);

    expect(files.deleted, ['a-file-a.mp3']);
    expect(tracks.saved.map((t) => t.id), ['b']);
    expect(find.text('Track a'), findsNothing);
    expect(find.text('Track b'), findsOneWidget);
  });

  testWidgets('a second swipe commits the first removal', (tester) async {
    await pumpDownloads(tester);
    await swipeAway(tester, 'Track a');
    await swipeAway(tester, 'Track b');
    await _settle(tester);

    expect(files.deleted, ['a-file-a.mp3']);
    expect(tracks.saved.map((t) => t.id), ['b']);

    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    expect(files.deleted, ['a-file-a.mp3', 'b-file-b.mp3']);
    expect(tracks.saved, isEmpty);
  });
}
