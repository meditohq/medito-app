import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/repositories/background_sounds/background_sounds_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<BackgroundSoundsRepository> repoWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
    );
    addTearDown(container.dispose);
    // Auto-disposed provider: keep it alive across the awaits below.
    container.listen(backgroundSoundsRepositoryProvider, (_, _) {});
    return container.read(backgroundSoundsRepositoryProvider);
  }

  test('bells default on for the timer and off under tracks', () async {
    final repo = await repoWith({});
    expect(repo.getSessionBellsEnabled(forTimer: true), isTrue);
    expect(repo.getSessionBellsEnabled(), isFalse);
    expect(repo.getSelectedBgSoundFromSharedPreferences(), isNull);
  });

  test('bells picked as the background sound migrate to the switch', () async {
    final repo = await repoWith({
      SharedPreferenceConstants.bgSound: jsonEncode(
        kSessionBellsSound.toJson(),
      ),
    });
    expect(repo.getSessionBellsEnabled(), isTrue);
    expect(repo.getSelectedBgSoundFromSharedPreferences(), isNull);
  });

  test('the switch is saved per scope', () async {
    final repo = await repoWith({});
    repo.saveSessionBellsEnabled(false, forTimer: true);
    repo.saveSessionBellsEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(repo.getSessionBellsEnabled(forTimer: true), isFalse);
    expect(repo.getSessionBellsEnabled(), isTrue);
  });

  test(
    'timer defaults to beginning/end, tracks retain the three cues',
    () async {
      final repo = await repoWith({});
      expect(
        repo.getSessionBellPattern(forTimer: true),
        SessionBellPattern.beginningEnd,
      );
      expect(
        repo.getSessionBellPattern(),
        SessionBellPattern.beginningMiddleEnd,
      );
    },
  );

  test('bell timing is remembered separately for timer and tracks', () async {
    final repo = await repoWith({});
    repo.saveSessionBellPattern(SessionBellPattern.everyMinute, forTimer: true);
    repo.saveSessionBellPattern(SessionBellPattern.beginningEnd);
    await Future<void>.delayed(Duration.zero);
    expect(
      repo.getSessionBellPattern(forTimer: true),
      SessionBellPattern.everyMinute,
    );
    expect(repo.getSessionBellPattern(), SessionBellPattern.beginningEnd);
  });

  test(
    'invalid saved timing falls back without changing explicit silence',
    () async {
      final repo = await repoWith({
        SharedPreferenceConstants.timerSessionBellsEnabled: false,
        SharedPreferenceConstants.timerSessionBellPattern: 'unknown',
      });
      expect(repo.getSessionBellsEnabled(forTimer: true), isFalse);
      expect(
        repo.getSessionBellPattern(forTimer: true),
        SessionBellPattern.beginningEnd,
      );
    },
  );
}
