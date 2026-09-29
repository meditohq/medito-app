import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/background_sounds/background_sounds_notifier.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/services/review_service.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/end_screen/end_screen_view.dart';
import 'package:medito/views/home/previews/home_previews.dart';
import 'package:medito/views/player/player_view.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/firebase_analytics_test_helper.dart';
import '../../helpers/firebase_test_helper.dart';

const _welcome = PlaybackRequest(
  trackId: 'welcome',
  fileId: 'welcome-file',
  title: 'Welcome',
  description: '',
  coverUrl: '',
  remoteUrl: 'https://example.test/welcome.mp3',
  duration: 48024,
  hasBackgroundSound: false,
  guideName: 'Will',
);

PlaybackState _state({
  required bool completed,
  required int positionMs,
  bool playing = false,
  String trackId = 'welcome',
}) {
  return PlaybackState(
    isPlaying: playing,
    isBuffering: false,
    isSeeking: false,
    isCompleted: completed,
    position: positionMs,
    duration: positionMs,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: trackId,
      title: '',
      fileId: '',
      description: '',
      imageUrl: '',
      artist: '',
    ),
  );
}

/// What the onboarding meditation leaves behind: finished, never stopped.
class _PreviousSessionCompleted extends AudioStateNotifier {
  @override
  PlaybackState build() => _state(
    completed: true,
    positionMs: 164028,
    playing: true,
    trackId: 'onboarding',
  );
}

class _FakePlayer extends PlayerProvider {
  final loaded = Completer<void>();
  int stops = 0;

  @override
  PlaybackRequest? build() => _welcome;

  @override
  Future<void> play(PlaybackRequest request) => loaded.future;

  @override
  void stop() => stops++;

  @override
  void setSpeed(double speed) {}
}

class _SilentBackgroundSounds extends BackgroundSoundsNotifier {
  @override
  void stopBackgroundSound() {}

  @override
  void playBackgroundSoundFromPref() {}
}

class _Stats extends StatsNotifier {
  @override
  Future<LocalAllStats> build() async => previewStats;
}

class _Review implements ReviewService {
  @override
  Future<void> checkAndRequestReview() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => 0,
    );
    await FirebaseTestHelper.initializeFirebaseForTest();
    FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks();
  });

  testWidgets(
    'a new player ignores the previous session\'s completed state and opens '
    'the end screen only for its own',
    (tester) async {
      final player = _FakePlayer();
      await tester.pumpWidget(
        PreviewShell(
          prefs: prefsDark,
          overrides: [
            playerProvider.overrideWith(() => player),
            audioStateProvider.overrideWith(_PreviousSessionCompleted.new),
            backgroundSoundsNotifierProvider.overrideWith(
              _SilentBackgroundSounds.new,
            ),
            statsProvider.overrideWith(_Stats.new),
            endScreenPaywallConfigProvider.overrideWith(
              (ref) => Completer<PaywallConfigModel>().future,
            ),
            reviewServiceProvider.overrideWithValue(_Review()),
            meProvider.overrideWith(
              (ref) async => const MeModel(id: 'test-user'),
            ),
            fetchDonationPageProvider.overrideWith(
              (ref) async => const DonationPageModel(
                title: 'Keep meditation free',
                text: 'Your support keeps Medito free.',
                buttons: [
                  ButtonModel(
                    title: 'Donate',
                    path: 'https://meditofoundation.org/donate',
                    type: 'link',
                  ),
                ],
              ),
            ),
          ],
          child: const PlayerView(),
        ),
      );
      final audio = ProviderScope.containerOf(
        tester.element(find.byType(PlayerView)),
      ).read(audioStateProvider.notifier);

      // Opening: the stale completed state is already there.
      await tester.pump();
      await tester.pump();
      expect(find.byType(EndScreenView), findsNothing);
      expect(find.byType(PlayerScreenLayout), findsOneWidget);
      expect(player.stops, 0);

      // While the new track loads: play() resets the state, then iOS
      // re-emits the old completed state until setUrl clears it.
      audio.resetState();
      await tester.pump();
      audio.updatePlaybackState(
        _state(completed: true, positionMs: 164028, trackId: 'onboarding'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(EndScreenView), findsNothing);
      expect(player.stops, 0);

      // The new track loads and plays.
      audio.updatePlaybackState(
        _state(completed: false, positionMs: 0, playing: true),
      );
      player.loaded.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(EndScreenView), findsNothing);
      expect(find.byType(PlayerScreenLayout), findsOneWidget);

      // It finishes: now the end screen opens.
      audio.updatePlaybackState(_state(completed: true, positionMs: 48024));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(EndScreenView), findsOneWidget);
      expect(player.stops, 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
