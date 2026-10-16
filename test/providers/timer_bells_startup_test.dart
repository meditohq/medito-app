import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/player/ios_audio_handler.dart';
import 'package:medito/providers/player/audio_state_provider.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/audio/ios_session_bells.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/audio_session_tracker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Handler extends Mock implements IosAudioHandler {}

class _Bells extends Mock implements IosSessionBells {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Handler handler;
  late _Bells bells;
  late ProviderContainer container;
  final request = timerPlaybackRequest(
    mode: TimerMode.countdown,
    duration: const Duration(minutes: 10),
    filePath: '/tmp/timer.wav',
    title: 'Timer',
  );

  setUpAll(() {
    registerFallbackValue(request);
    registerFallbackValue(
      Track(
        id: '',
        title: '',
        fileId: '',
        artist: '',
        description: '',
        imageUrl: '',
      ),
    );
    registerFallbackValue(RepeatMode.none);
    registerFallbackValue(SessionBellPattern.beginningEnd);
    AudioSessionTracker.logSink = (_, _) async {};
  });

  Future<void> setup(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioStateProvider.overrideWith(AudioStateNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    handler = _Handler();
    bells = _Bells();
    iosAudioHandler = handler;
    when(() => handler.sessionBells).thenReturn(bells);
    when(() => handler.setCustomRepeatMode(any())).thenAnswer((_) async {});
    when(() => handler.setSpeed(any())).thenAnswer((_) async {});
    when(() => handler.setUrl(null, any(), any())).thenAnswer((_) async {});
    when(() => handler.play()).thenAnswer((_) async {});
    when(
      () => bells.enable(any(), pattern: any(named: 'pattern')),
    ).thenAnswer((_) async {});
    when(() => bells.disable()).thenAnswer((_) async {});
  }

  test(
    'timer waits for bundled bells before starting primary playback',
    () async {
      await setup({});
      final ready = Completer<void>();
      final preparing = Completer<void>();
      when(
        () => bells.enable(any(), pattern: SessionBellPattern.beginningEnd),
      ).thenAnswer((_) {
        preparing.complete();
        return ready.future;
      });
      final starting = container.read(playerProvider.notifier).play(request);
      await preparing.future;
      verify(() => handler.setUrl(null, any(), any())).called(1);
      verifyNever(() => handler.play());
      final state = container.read(backgroundSoundsNotifierProvider);
      expect(state.bellsEnabled, isTrue);
      expect(state.bellPattern, SessionBellPattern.beginningEnd);
      expect(state.selectedBgSound, isNull);
      ready.complete();
      await starting;
      verify(() => handler.play()).called(1);
    },
  );

  test(
    'startup restores saved volume and minute bells without an ambient sound',
    () async {
      await setup({
        SharedPreferenceConstants.bgSoundVolume: 80.0,
        SharedPreferenceConstants.timerSessionBellPattern: 'everyMinute',
      });
      await container.read(playerProvider.notifier).play(request);
      verify(
        () => bells.enable(.4, pattern: SessionBellPattern.everyMinute),
      ).called(1);
      expect(container.read(backgroundSoundsNotifierProvider).volume, 80);
    },
  );

  test('an explicit timer opt-out stays silent on the next session', () async {
    await setup({SharedPreferenceConstants.timerSessionBellsEnabled: false});
    await container.read(playerProvider.notifier).play(request);
    verify(() => bells.disable()).called(1);
    verifyNever(() => bells.enable(any(), pattern: any(named: 'pattern')));
    verify(() => handler.play()).called(1);
  });
}
