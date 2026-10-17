import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/background_sound/background_sound_view.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/previews/preview_support.dart' show MemoryPrefs;

const _sounds = [
  BackgroundSoundsModel(id: 'rain', title: 'Rain', path: '', duration: 60000),
  BackgroundSoundsModel(id: 'river', title: 'River', path: '', duration: 60000),
  BackgroundSoundsModel(
    id: 'forest',
    title: 'Forest',
    path: '',
    duration: 60000,
  ),
];

class _Bells extends BackgroundSoundsNotifier {
  @override
  BackgroundSoundsState build() => const BackgroundSoundsState(
    bellsEnabled: true,
    bellPattern: SessionBellPattern.beginningEnd,
  );

  @override
  void setSessionBellCue(SessionBellCue cue, bool selected) {
    final pattern = state.selectedBellPattern.withCue(cue, selected);
    state = state.copyWith(
      bellPattern: pattern,
      bellsEnabled: pattern != SessionBellPattern.none,
    );
  }
}

class _Audio extends AudioStateNotifier {
  @override
  PlaybackState build() => PlaybackState(
    position: 154000,
    duration: 600000,
    isPlaying: false,
    isBuffering: false,
    isSeeking: false,
    isCompleted: false,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: 'timer-600',
      title: 'Timer',
      fileId: '',
      description: '',
      imageUrl: '',
      artist: '',
    ),
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image cover;
  setUpAll(() async {
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

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('real sound sheet fits ${size.width} at ${scale}x text', (
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
        final provider = ResizeImage.resizeIfNeeded(
          size.width.toInt(),
          null,
          const NetworkImage(coverUrl),
        );
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
            child: ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(
                  MemoryPrefs({
                    SharedPreferenceConstants.bgSoundChangeHintShown: true,
                  }),
                ),
                audioStateProvider.overrideWith(_Audio.new),
                backgroundSoundsNotifierProvider.overrideWith(_Bells.new),
                backgroundSoundsProvider.overrideWith((_) async => _sounds),
                backgroundSoundCatalogProvider.overrideWithValue(
                  const BackgroundSoundCatalog(
                    sounds: _sounds,
                    downloadedIds: {},
                    offline: false,
                    loading: false,
                  ),
                ),
              ],
              child: Builder(
                builder: (context) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: appTheme(context, ThemeMode.dark),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: PlayerScreenLayout(
                    currentlyPlayingTrack: timerPlaybackRequest(
                      mode: TimerMode.countdown,
                      duration: const Duration(minutes: 10),
                      filePath: '/preview/timer.wav',
                      title: 'Timer',
                      coverUrl: coverUrl,
                    ),
                    isPlaying: false,
                    isAudioLoading: false,
                    isBackgroundSoundSelected: false,
                    onPlayPausePressed: () {},
                    onSpeedChanged: (_) {},
                    onClosePressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));
        await tester.tap(find.byTooltip('Background Sound'));
        await tester.pumpAndSettle();
        expect(find.byType(BackgroundSoundView), findsOneWidget);
        expect(find.byType(Checkbox), findsNWidgets(3));
        expect(find.byType(Switch), findsNothing);
        expect(
          find.byType(DropdownButtonFormField<SessionBellPattern>),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        // Export the production widgets, with the timer behind the real sheet.
        const output = String.fromEnvironment('BELL_SHEET_SCREENSHOTS');
        if (output.isNotEmpty && size.width == 390 && scale == 1) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/medito-timer-bells-checkboxes.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
