import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/views/downloads/widgets/download_list_item.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/downloads/downloads_view.dart';
import 'package:medito/services/watch_download_service.dart';

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

class _FakeWatchDownloads implements WatchDownloadService {
  Completer<void>? pendingSend;
  final sent = <Track>[];
  final removed = <Map<String, dynamic>>[];
  @override
  Future<void> send(Track track) async {
    sent.add(track);
    await pendingSend?.future;
  }

  @override
  Future<void> remove(Map<String, dynamic> item) async => removed.add(item);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('download cards fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Theme(
              data: appTheme(context, mode),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: Scaffold(
                  body: ReorderableListView(
                    padding: const EdgeInsets.all(20),
                    onReorderItem: (_, _) {},
                    children: const [
                      DownloadListItemWidget(
                        key: ValueKey('long-track'),
                        title: 'A longer meditation title for a quiet evening',
                        subtitle: 'A guide with a longer name · 20 minutes',
                        coverUrl: '',
                        index: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 280, child: DownloadListShimmer()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  late _FakeTrackRepository tracks;
  late _FakeDownloaderRepository files;
  late _FakeWatchDownloads watchService;

  Future<void> pumpDownloads(
    WidgetTester tester, {
    WatchDownloads watch = const WatchDownloads(),
    Stream<WatchDownloads>? watchStream,
  }) async {
    tracks = _FakeTrackRepository([_track('a'), _track('b')]);
    files = _FakeDownloaderRepository();
    watchService = _FakeWatchDownloads();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchDownloadsProvider.overrideWith(
            (_) => watchStream ?? Stream.value(watch),
          ),
          watchDownloadServiceProvider.overrideWithValue(watchService),
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
  testWidgets(
    'tabs remain visible and unavailable watch has a clear empty state',
    (tester) async {
      await pumpDownloads(tester);
      expect(find.text('On watch'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.text('On watch'));
      await _settle(tester);
      expect(find.text('No watch connected'), findsOneWidget);
    },
  );

  testWidgets('tabs appear before watch discovery finishes', (tester) async {
    final discovery = Completer<WatchDownloads>();
    await pumpDownloads(tester, watchStream: discovery.future.asStream());
    expect(find.text('On phone'), findsOneWidget);
    expect(find.text('On watch'), findsOneWidget);
    await tester.tap(find.text('On watch'));
    await _settle(tester);
    expect(find.text('Checking watch…'), findsOneWidget);
    expect(find.text('No watch connected'), findsNothing);
    discovery.complete(const WatchDownloads());
    await _settle(tester);
    expect(find.text('No watch connected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final state in ['queued', 'sending', 'ready']) {
    testWidgets(
      'phone menu does not offer Send again for $state watch copies',
      (tester) async {
        await pumpDownloads(
          tester,
          watch: WatchDownloads(
            available: true,
            items: [
              {'fileId': 'file-a', 'title': 'Track a', 'state': state},
            ],
          ),
        );
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await _settle(tester);
        expect(find.text('Send to watch'), findsNothing);
        expect(
          find.text(state == 'ready' ? 'Remove from watch' : 'Cancel transfer'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('failed phone send offers Retry rather than a fresh send', (
    tester,
  ) async {
    await pumpDownloads(
      tester,
      watch: const WatchDownloads(
        available: true,
        items: [
          {'fileId': 'file-a', 'title': 'Track a', 'state': 'failed'},
        ],
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await _settle(tester);
    expect(find.text('Send to watch'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(watchService.sent.single.id, 'a');
  });

  testWidgets('bulk selection cannot select a ready watch copy', (
    tester,
  ) async {
    await pumpDownloads(
      tester,
      watch: const WatchDownloads(
        available: true,
        items: [
          {'fileId': 'file-a', 'title': 'Track a', 'state': 'ready'},
        ],
      ),
    );
    await tester.tap(find.text('Select'));
    await _settle(tester);
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      isNull,
    );
    await tester.tap(find.byType(Checkbox).last);
    await _settle(tester);
    await tester.tap(find.text('Send to watch'));
    await _settle(tester);
    expect(watchService.sent.map((track) => track.id), ['b']);
  });

  testWidgets('sending opens watch downloads and sends the selected variant', (
    tester,
  ) async {
    await pumpDownloads(tester, watch: const WatchDownloads(available: true));
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await _settle(tester);
    await tester.tap(find.text('Send to watch'));
    await _settle(tester);
    expect(watchService.sent.single.voices.first.audioFiles.first.id, 'file-a');
    expect(
      find.text('Send sessions from On phone to listen offline on your watch.'),
      findsOneWidget,
    );
    expect(files.deleted, isEmpty);
  });

  testWidgets(
    'watch-only sessions remain visible and removing them keeps phone downloads',
    (tester) async {
      await pumpDownloads(
        tester,
        watch: const WatchDownloads(
          available: true,
          items: [
            {
              'fileId': 'watch-only',
              'title': 'Watch only session',
              'durationMs': 600000,
              'state': 'ready',
            },
          ],
        ),
      );
      await tester.tap(find.text('On watch'));
      await _settle(tester);
      expect(find.text('Watch only session'), findsOneWidget);
      expect(find.text('Ready on watch'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await _settle(tester);
      await tester.tap(find.text('Remove from watch'));
      await _settle(tester);
      expect(watchService.removed.single['fileId'], 'watch-only');
      expect(files.deleted, isEmpty);
      expect(tracks.saved.length, 2);
    },
  );

  testWidgets(
    'a queued transfer is never labelled ready and can be cancelled',
    (tester) async {
      await pumpDownloads(
        tester,
        watch: const WatchDownloads(
          available: true,
          items: [
            {
              'fileId': 'file-a',
              'title': 'Track a',
              'durationMs': 600000,
              'state': 'queued',
            },
          ],
        ),
      );
      await tester.tap(find.text('On watch'));
      await _settle(tester);
      expect(find.text('Waiting for watch'), findsOneWidget);
      expect(find.text('Ready on watch'), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await _settle(tester);
      await tester.tap(find.text('Cancel transfer'));
      await _settle(tester);
      expect(watchService.removed.single['fileId'], 'file-a');
    },
  );

  testWidgets('failed transfers explain storage and offer retry', (
    tester,
  ) async {
    await pumpDownloads(
      tester,
      watch: const WatchDownloads(
        available: true,
        items: [
          {
            'fileId': 'file-a',
            'title': 'Track a',
            'durationMs': 600000,
            'state': 'failed',
            'error': 'storage_full',
          },
        ],
      ),
    );
    await tester.tap(find.text('On watch'));
    await _settle(tester);
    expect(
      find.text(
        'Not enough space on your watch. Remove some downloads and try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await _settle(tester);
    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(watchService.sent.single.id, 'a');
  });
  testWidgets(
    'send shows a spinner immediately and disables its row menu until queued',
    (tester) async {
      await pumpDownloads(tester, watch: const WatchDownloads(available: true));
      watchService.pendingSend = Completer<void>();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await _settle(tester);
      await tester.tap(find.text('Send to watch'));
      await _settle(tester);
      expect(find.text('Checking watch…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(watchService.sent.length, 1);
      watchService.pendingSend!.complete();
      await _settle(tester);
      expect(find.text('Checking watch…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'sending watch rows show activity even without numeric progress',
    (tester) async {
      await pumpDownloads(
        tester,
        watch: const WatchDownloads(
          available: true,
          items: [
            {'fileId': 'file-a', 'title': 'Track a', 'state': 'sending'},
          ],
        ),
      );
      await tester.tap(find.text('On watch'));
      await _settle(tester);
      expect(find.text('Sending…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    },
  );

  testWidgets('Select sends multiple chosen sessions without playing them', (
    tester,
  ) async {
    await pumpDownloads(tester, watch: const WatchDownloads(available: true));
    await tester.tap(find.text('Select'));
    await _settle(tester);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await _settle(tester);
    await tester.tap(find.text('Send to watch'));
    await _settle(tester);
    expect(watchService.sent.map((track) => track.id), ['a', 'b']);
    expect(files.deleted, isEmpty);
  });
}
