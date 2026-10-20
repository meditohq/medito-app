import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/track/track_repository.dart';
import 'package:medito/views/previews/preview_support.dart' show MemoryPrefs;
import 'package:medito/views/timer/timer_view.dart';
import 'package:medito/views/timer/widgets/timer_bells_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/firebase_analytics_test_helper.dart';
import '../helpers/firebase_test_helper.dart';

class _Tracks extends Mock implements TrackRepository {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Tracks tracks;
  late ui.Image cover;
  setUpAll(() async {
    await FirebaseTestHelper.initializeFirebaseForTest();
    FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks();
    for (final entry in {
      'Google Sans': 'assets/fonts/google-sans/GoogleSans-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    final bytes = await rootBundle.load('assets/images/open_awareness.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    cover = (await codec.getNextFrame()).image;
    codec.dispose();
  });
  tearDownAll(() => cover.dispose());
  setUp(() {
    tracks = _Tracks();
    when(() => tracks.fetchTrack(any())).thenAnswer(
      (_) async => const Track(
        id: 'timer',
        title: 'Timer',
        description: '',
        coverUrl: '',
        isPublished: true,
        hasBackgroundSound: true,
      ),
    );
  });

  Widget screen(MemoryPrefs prefs, {double textScale = 1}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      trackRepositoryProvider.overrideWithValue(tracks),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(context, ThemeMode.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TimerView(source: 'test'),
      ),
    ),
  );

  Future<void> openBells(WidgetTester tester) async {
    final row = find.byType(TimerBellsTile);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> closeBells(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(TimerBellsSheet))).pop();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sheet saves choices and setup summarizes them across reopening',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = MemoryPrefs({});
      await tester.pumpWidget(screen(prefs));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Beginning and end'), findsOneWidget);
      await openBells(tester);
      List<bool?> selections() => tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((checkbox) => checkbox.value)
          .toList();
      expect(selections(), [true, false, true]);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Middle'));
      await tester.pumpAndSettle();
      expect(selections(), [true, true, true]);
      await closeBells(tester);
      expect(find.text('Beginning, middle and end'), findsOneWidget);
      await tester.tap(find.text('Stopwatch'));
      await tester.pumpAndSettle();
      await openBells(tester);
      expect(selections(), [true, true, true]);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beginning'));
      await tester.pumpAndSettle();
      expect(selections(), [false, true, true]);
      await closeBells(tester);
      expect(find.text('Middle · End'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen(prefs));
      await tester.pumpAndSettle();
      expect(find.text('Middle · End'), findsOneWidget);
      await openBells(tester);
      expect(selections(), [false, true, true]);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Middle'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'End'));
      await tester.pumpAndSettle();
      await closeBells(tester);
      expect(find.text('None'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets('timer bells accessible with cover at $size and ${scale}x', (
      tester,
    ) async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      const coverUrl = 'https://preview.medito.test/timer-cover.png';
      final provider = const CachedNetworkImageProvider(coverUrl);
      final imageKey = await provider.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(
        imageKey,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: cover.clone())),
        ),
      );
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: screen(
            MemoryPrefs({SharedPreferenceConstants.timerCoverUrl: coverUrl}),
            textScale: scale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TimerBellsTile));
      await tester.pumpAndSettle();
      const output = String.fromEnvironment('TIMER_BELL_SCREENSHOTS');
      Future<void> screenshot(String name) async {
        if (output.isEmpty || scale != 1) return;
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await screenshot('medito-timer-bells-summary');
      await openBells(tester);
      final end = find.widgetWithText(CheckboxListTile, 'End');
      await tester.ensureVisible(end);
      await tester.pumpAndSettle();
      expect(end.hitTestable(), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.byType(Switch), findsNothing);
      expect(tester.takeException(), isNull);
      await screenshot('medito-timer-bells-bottom-sheet');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
