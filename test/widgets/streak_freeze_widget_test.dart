import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/streak_freeze_suggestion_widget.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/widgets/medito_huge_icon.dart';

// Test implementation of FeatureFlagsNotifier
class TestFeatureFlagsNotifier extends FeatureFlagsNotifier {
  final bool isStreakFreezeEnabled;

  TestFeatureFlagsNotifier({required this.isStreakFreezeEnabled});

  @override
  FeatureFlags build() {
    return FeatureFlags(isStreakFreezeEnabled: isStreakFreezeEnabled);
  }
}

void main() {
  group('Streak Freeze Widget Tests', () {
    testWidgets(
        'StreakFreezeSuggestionWidget should display correctly when feature is enabled',
        (WidgetTester tester) async {
      // Create test stats with available freezes
      final testStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime.now().millisecondsSinceEpoch),
        ],
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: DateTime.now().millisecondsSinceEpoch,
        streakFreezes: 2, // 2 available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      var onUseFreezeCallCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override feature flags to enable streak freeze
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: Scaffold(
              body: StreakFreezeSuggestionWidget(
                stats: testStats,
                onUseFreeze: () {
                  onUseFreezeCallCount++;
                },
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify the main elements are displayed
      expect(find.text('You missed a day'), findsOneWidget);
      expect(find.textContaining('2 streak freezes available'), findsOneWidget);
      expect(find.text('Use Streak Freeze'), findsOneWidget);

      // Verify that freeze icons are displayed (MeditoIcon for available freezes)
      expect(find.byType(MeditoIcon),
          findsAtLeast(2)); // Should have 2 freeze icons

      // Test tapping the "Use Streak Freeze" button
      await tester.tap(find.text('Use Streak Freeze'));
      await tester.pumpAndSettle();

      // Verify the callback was called
      expect(onUseFreezeCallCount, 1);
    });

    testWidgets(
        'StreakFreezeSuggestionWidget should not display when feature is disabled',
        (WidgetTester tester) async {
      final testStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime.now().millisecondsSinceEpoch),
        ],
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: DateTime.now().millisecondsSinceEpoch,
        streakFreezes: 2,
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override feature flags to disable streak freeze
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: false)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: Scaffold(
              body: StreakFreezeSuggestionWidget(
                stats: testStats,
                onUseFreeze: () {},
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify the widget is not displayed (returns SizedBox.shrink)
      expect(find.text('You missed a day'), findsNothing);
      expect(find.text('Use Streak Freeze'), findsNothing);
    });

    testWidgets(
        'StreakFreezeSuggestionWidget should display correct freeze count',
        (WidgetTester tester) async {
      final testStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime.now().millisecondsSinceEpoch),
        ],
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: DateTime.now().millisecondsSinceEpoch,
        streakFreezes: 1, // 1 available out of 3 total
        maxStreakFreezes: 3,
        freezeUsageDates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override feature flags to enable streak freeze
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: Scaffold(
              body: StreakFreezeSuggestionWidget(
                stats: testStats,
                onUseFreeze: () {},
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify the correct freeze count is displayed
      expect(find.textContaining('1 streak freezes available'), findsOneWidget);

      // Verify correct number of icons (3 total, 1 available MeditoIcon, 2 used Container circles)
      expect(find.byType(MeditoIcon),
          findsAtLeast(1)); // At least 1 available freeze icon
      expect(find.byType(Container),
          findsAtLeast(2)); // At least 2 used freeze circles
    });

    testWidgets(
        'StreakFreezeSuggestionWidget should disable button when no freezes available',
        (WidgetTester tester) async {
      final testStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime.now().millisecondsSinceEpoch),
        ],
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: DateTime.now().millisecondsSinceEpoch,
        streakFreezes: 0, // No available freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override feature flags to enable streak freeze
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: Scaffold(
              body: StreakFreezeSuggestionWidget(
                stats: testStats,
                onUseFreeze: () {},
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Find the ElevatedButton
      final button = find.widgetWithText(ElevatedButton, 'Use Streak Freeze');
      expect(button, findsOneWidget);

      // Verify the button is disabled
      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNull);
    });
  });

  group('Feature Flag Tests', () {
    testWidgets('Feature flag provider should return enabled state',
        (WidgetTester tester) async {
      // Set up SharedPreferences with default enabled state
      SharedPreferences.setMockInitialValues({'streak_freeze_enabled': true});
      var prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                final featureFlags = ref.watch(featureFlagsProvider);
                return Text(featureFlags.isStreakFreezeEnabled.toString());
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the feature flag is enabled
      expect(find.text('true'), findsOneWidget);
    });
  });
}
