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
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/background_sound/background_sound_view.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/player/widgets/bottom_actions/widgets/bg_sound_widget.dart';
import 'package:medito/views/previews/preview_support.dart' show MemoryPrefs;

const _hint = 'Tap here to change background sounds or bells.';
const _track = PlaybackRequest(
  trackId: 'preview',
  fileId: 'preview-file',
  title: 'Noting Thoughts',
  description: '',
  coverUrl: 'https://preview.medito.test/cover.png',
  remoteUrl: 'https://example.test/audio.mp3',
  duration: 600000,
  hasBackgroundSound: true,
  guideName: 'Will',
);

class _Audio extends AudioStateNotifier {
  @override
  PlaybackState build() => PlaybackState(
    position: 154000,
    duration: 600000,
    isPlaying: true,
    isBuffering: false,
    isSeeking: false,
    isCompleted: false,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: 'preview',
      title: 'Noting Thoughts',
      fileId: 'preview-file',
      description: '',
      imageUrl: '',
      artist: 'Will',
    ),
  );
}

class _Ambient extends BackgroundSoundsNotifier {
  _Ambient({this.bellsOnly = false});

  final bool bellsOnly;

  @override
  BackgroundSoundsState build() => BackgroundSoundsState(
    bellsEnabled: bellsOnly,
    selectedBgSound: bellsOnly
        ? null
        : const BackgroundSoundsModel(
            id: 'rain',
            title: 'Rain',
            path: 'rain.mp3',
            duration: 1000,
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

  const screens = {
    'small-phone': Size(320, 568),
    'phone': Size(390, 844),
    'large-phone': Size(430, 932),
    'small-landscape': Size(568, 320),
    'landscape': Size(844, 390),
    'tablet': Size(768, 1024),
    'wide-tablet': Size(1200, 800),
  };
  for (final screen in screens.entries) {
    for (final textScale in [1.0, 2.0]) {
      for (final timer in [false, true]) {
        testWidgets(
          '${screen.key} ${screen.value.width.toInt()}x${screen.value.height.toInt()} '
          '${textScale}x text ${timer ? 'timer' : 'track'}: tooltip fits and closes',
          (tester) async {
            binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = screen.value;
            final landscape = screen.value.width > screen.value.height;
            tester.view.padding = FakeViewPadding(
              top: landscape ? 0 : 47,
              bottom: landscape ? 20 : 34,
              left: landscape ? 16 : 0,
              right: landscape ? 16 : 0,
            );
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);

            final provider = ResizeImage.resizeIfNeeded(
              screen.value.width.toInt(),
              null,
              NetworkImage(_track.coverUrl),
            );
            final key = await provider.obtainKey(ImageConfiguration.empty);
            PaintingBinding.instance.imageCache.putIfAbsent(
              key,
              () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: cover.clone())),
              ),
            );
            final prefs = MemoryPrefs({
              SharedPreferenceConstants.bgSoundPlayerVisits: 1,
            });
            final capture = GlobalKey();
            var playerClosed = false;
            await tester.pumpWidget(
              RepaintBoundary(
                key: capture,
                child: ProviderScope(
                  overrides: [
                    sharedPreferencesProvider.overrideWithValue(prefs),
                    audioStateProvider.overrideWith(_Audio.new),
                    backgroundSoundsNotifierProvider.overrideWith(
                      () => _Ambient(bellsOnly: timer),
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
                        ).copyWith(textScaler: TextScaler.linear(textScale)),
                        child: child!,
                      ),
                      home: PlayerScreenLayout(
                        currentlyPlayingTrack: timer
                            ? timerPlaybackRequest(
                                mode: TimerMode.countdown,
                                duration: const Duration(minutes: 10),
                                filePath: '/preview/silence.wav',
                                title: 'Timer',
                                coverUrl: _track.coverUrl,
                              )
                            : _track,
                        isPlaying: true,
                        isAudioLoading: false,
                        isBackgroundSoundSelected: true,
                        onPlayPausePressed: () {},
                        onSpeedChanged: (_) {},
                        onClosePressed: () => playerClosed = true,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 800));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 2200));

            final hint = find.text(_hint);
            expect(hint, findsOneWidget);
            final bubble = tester.getRect(
              find
                  .ancestor(of: hint, matching: find.byType(DecoratedBox))
                  .first,
            );
            final soundButton = find
                .ancestor(
                  of: find.byType(BgSoundWidget),
                  matching: find.byType(IconButton),
                )
                .first;
            final button = tester.getRect(soundButton);
            final close = find.byTooltip('Dismiss tip');
            final closeRect = tester.getRect(close);
            expect(bubble.left, greaterThanOrEqualTo(12));
            expect(bubble.right, lessThanOrEqualTo(screen.value.width - 12));
            expect(bubble.top, greaterThanOrEqualTo(0));
            expect(bubble.bottom, lessThanOrEqualTo(button.top));
            expect(bubble.contains(closeRect.center), isTrue);
            expect(closeRect.shortestSide, greaterThanOrEqualTo(44));
            expect(close.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);

            // Optionally export real rendered screens for visual inspection.
            const output = String.fromEnvironment('PLAYER_LAYOUT_SCREENSHOTS');
            if (output.isNotEmpty && !timer) {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1.5);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(output).create(recursive: true);
                await File(
                  '$output/${screen.key}-${textScale}x.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }

            await tester.tap(close);
            await tester.pump();
            expect(find.text(_hint), findsNothing);
            expect(find.byType(BackgroundSoundView), findsNothing);
            expect(playerClosed, isFalse);
            expect(
              prefs.getBool(SharedPreferenceConstants.bgSoundChangeHintShown),
              isTrue,
            );
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
