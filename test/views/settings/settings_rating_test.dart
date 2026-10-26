import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/review_service.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/settings/settings_screen.dart';

class _Stats extends StatsNotifier {
  final int count;
  _Stats(this.count);
  @override
  Future<LocalAllStats> build() async =>
      LocalAllStats.empty().copyWith(totalTracksCompleted: count);
}

class _Analytics implements FirebaseAnalyticsService {
  final events = <String>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(name);
    expect(
      parameters?[AnalyticsEventConstants.paramSource],
      AnalyticsEventConstants.sourceSettings,
    );
  }
}

void main() {
  for (final count in [4, 5]) {
    testWidgets(
      'Settings rating eligibility at $count sessions and tap analytics',
      (tester) async {
        final analytics = _Analytics();
        var opens = 0;
        await tester.pumpWidget(
          PreviewShell(
            prefs: const {},
            locale: const Locale('en'),
            overrides: [
              statsProvider.overrideWith(() => _Stats(count)),
              analyticsServiceProvider.overrideWithValue(analytics),
              reviewServiceProvider.overrideWithValue(
                ReviewService(
                  openStore: () async {
                    opens++;
                  },
                ),
              ),
            ],
            child: const SettingsScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (count < 5) {
          expect(find.text('Rate Medito'), findsNothing);
          expect(analytics.events, isEmpty);
          expect(opens, 0);
        } else {
          expect(find.text('Rate Medito'), findsOneWidget);
          expect(analytics.events, [
            AnalyticsEventConstants.settingsRateAvailable,
          ]);
          expect(opens, 0);
          await tester.ensureVisible(find.text('Rate Medito'));
          await tester.pumpAndSettle();
          expect(analytics.events, [
            AnalyticsEventConstants.settingsRateAvailable,
          ]);
          await tester.tap(find.text('Rate Medito'));
          await tester.pumpAndSettle();
          expect(opens, 1);
          expect(analytics.events, [
            AnalyticsEventConstants.settingsRateAvailable,
            AnalyticsEventConstants.settingsRateTap,
          ]);
        }
      },
    );
  }
}
