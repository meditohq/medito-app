import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/settings/analytics_reconsent_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  /// The stuck cohort: iOS, analytics off with no recorded source.
  const stuckPrefs = <String, Object>{
    SharedPreferenceConstants.analyticsFirebaseEnabled: false,
  };

  Future<ProviderContainer> containerWith(
    Map<String, Object> values, {
    bool attAuthorized = false,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        attAuthorizedProvider.overrideWith((ref) async => attAuthorized),
      ],
    );
    addTearDown(container.dispose);
    // Let the ATT future resolve.
    await container.read(attAuthorizedProvider.future);
    return container;
  }

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('shouldShowAnalyticsReconsentProvider', () {
    test('shows for an iOS opt-out with ATT declined', () async {
      final c = await containerWith(stuckPrefs);
      expect(c.read(shouldShowAnalyticsReconsentProvider), isTrue);
    });

    test(
      'never shows on Android, where every opt-out is the user\'s',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final c = await containerWith(stuckPrefs);
        expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
      },
    );

    test('hidden while analytics is on or never set', () async {
      final on = await containerWith({
        SharedPreferenceConstants.analyticsFirebaseEnabled: true,
      });
      expect(on.read(shouldShowAnalyticsReconsentProvider), isFalse);

      final unset = await containerWith({});
      expect(unset.read(shouldShowAnalyticsReconsentProvider), isFalse);
    });

    test(
      'hidden when ATT is authorised: that opt-out was the user\'s',
      () async {
        final c = await containerWith(stuckPrefs, attAuthorized: true);
        expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
      },
    );

    test(
      'hidden when the opt-out was made on the Data Collection screen',
      () async {
        final c = await containerWith({
          ...stuckPrefs,
          SharedPreferenceConstants.analyticsOptOutSource:
              SharedPreferenceConstants.analyticsOptOutSourceSettings,
        });
        expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
      },
    );

    test('hidden until the ATT status is known', () async {
      SharedPreferences.setMockInitialValues(stuckPrefs);
      prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          attAuthorizedProvider.overrideWith(
            (ref) => Future<bool>.delayed(const Duration(days: 1), () => false),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
    });

    test('stops after the impression cap without an answer', () async {
      final c = await containerWith(stuckPrefs);
      final notifier = c.read(analyticsReconsentProvider.notifier);
      for (var i = 0; i < analyticsReconsentMaxImpressions - 1; i++) {
        await notifier.recordImpression();
        expect(c.read(shouldShowAnalyticsReconsentProvider), isTrue);
      }
      await notifier.recordImpression();
      expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
      expect(
        prefs.getInt(SharedPreferenceConstants.analyticsReconsentImpressions),
        analyticsReconsentMaxImpressions,
      );
    });
  });

  group('AnalyticsReconsentNotifier.answer', () {
    test(
      'a decline is stored, leaves analytics off and never asks again',
      () async {
        final c = await containerWith(stuckPrefs);
        await c
            .read(analyticsReconsentProvider.notifier)
            .answer(accepted: false);

        expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);
        expect(
          prefs.getString(SharedPreferenceConstants.analyticsReconsentAnswer),
          analyticsReconsentDeclined,
        );
        expect(
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled),
          isFalse,
        );
      },
    );

    test('an accept is stored and survives a restart', () async {
      final c = await containerWith(stuckPrefs);
      await c.read(analyticsReconsentProvider.notifier).answer(accepted: true);
      expect(c.read(shouldShowAnalyticsReconsentProvider), isFalse);

      final restarted = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          attAuthorizedProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(restarted.dispose);
      await restarted.read(attAuthorizedProvider.future);
      expect(
        restarted.read(analyticsReconsentProvider).answer,
        analyticsReconsentAccepted,
      );
      expect(restarted.read(shouldShowAnalyticsReconsentProvider), isFalse);
    });
  });
}
